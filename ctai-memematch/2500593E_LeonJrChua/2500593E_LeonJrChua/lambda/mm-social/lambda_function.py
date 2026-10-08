
import decimal
import json
import os
from datetime import date, datetime

import boto3
import pymysql

DB_SECRET_NAME = os.environ["DB_SECRET_NAME"]
DB_NAME = os.environ.get("DB_NAME", "memematch")
SNS_TOPIC_ARN = os.environ.get("SNS_TOPIC_ARN", "")
ALLOWED_ORIGIN = os.environ.get("ALLOWED_ORIGIN", "*")

MAX_COMMENT = 280

_secret = None
_connection = None
_sns = boto3.client("sns") if SNS_TOPIC_ARN else None


# --- plumbing ----------------------------------------------------------

def _json_default(value):
    if isinstance(value, decimal.Decimal):
        return float(value)
    if isinstance(value, (datetime, date)):
        return value.isoformat() + "Z"
    raise TypeError(f"{type(value)} is not JSON serialisable")


def _respond(status, body):
    return {
        "statusCode": status,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
            "Access-Control-Allow-Headers": "Content-Type,Authorization",
            "Access-Control-Allow-Methods": "GET,POST,DELETE,OPTIONS",
        },
        "body": json.dumps(body, default=_json_default),
    }


def _get_secret():
    global _secret
    if _secret is None:
        client = boto3.client("secretsmanager")
        raw = client.get_secret_value(SecretId=DB_SECRET_NAME)["SecretString"]
        _secret = json.loads(raw)
    return _secret


def _connect():
    global _connection

    if _connection is not None:
        try:
            _connection.ping(reconnect=True)
            return _connection
        except Exception:
            _connection = None

    secret = _get_secret()
    _connection = pymysql.connect(
        host=secret["host"],
        user=secret["username"],
        password=secret["password"],
        database=secret.get("dbname", DB_NAME),
        port=int(secret.get("port", 3306)),
        cursorclass=pymysql.cursors.DictCursor,
        connect_timeout=5,
        autocommit=False,
    )
    return _connection


def _claims(event):
    """
    Verified Cognito claims, or None for an unauthenticated request.

    HTTP API (payload format 2.0) nests these under "jwt"; REST API (1.0) does
    not. Reading both means this works whichever API type is deployed.
    """
    authorizer = (event.get("requestContext") or {}).get("authorizer") or {}

    if "jwt" in authorizer:
        return authorizer["jwt"].get("claims")

    return authorizer.get("claims")


def _method(event):
    """HTTP method, from either payload format."""
    return (
        event.get("httpMethod")
        or ((event.get("requestContext") or {}).get("http") or {}).get("method")
        or ""
    )


def _route(event):
    """
    The route template, e.g. "/posts/{postId}/likes".

    REST API exposes it as `resource`. HTTP API embeds it in `routeKey`, as
    "POST /posts/{postId}/likes".
    """
    if event.get("resource"):
        return event["resource"]

    route_key = event.get("routeKey") or ""

    if " " in route_key:
        return route_key.split(" ", 1)[1]

    return ((event.get("requestContext") or {}).get("http") or {}).get("path", "")


def _body(event):
    try:
        return json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return {}


def _notify(recipient_id, actor, kind, text):
    """
    Publish an activity event. Failures are logged and swallowed: a like or
    comment that succeeded must not report an error because SNS was unreachable.
    """
    if not _sns or not recipient_id:
        return

    try:
        _sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject="MemeMatch activity",
            Message=json.dumps({"kind": kind, "actor": actor, "text": text}),
            MessageAttributes={
                "recipient": {"DataType": "String", "StringValue": recipient_id},
                "kind": {"DataType": "String", "StringValue": kind},
            },
        )
    except Exception as error:
        print(f"WARN sns publish failed: {type(error).__name__}: {error}")


# --- notification subscriptions ----------------------------------------

def _subscription_arn(email):
    """
    SubscriptionArn for this address on the activity topic, or None.

    ListSubscriptionsByTopic has no server-side filter on Endpoint, so this
    pages through and matches locally. An address that has been sent a
    confirmation email but has not clicked it reports the literal string
    "PendingConfirmation" in place of an ARN.
    """
    token = None

    while True:
        kwargs = {"TopicArn": SNS_TOPIC_ARN}

        if token:
            kwargs["NextToken"] = token

        response = _sns.list_subscriptions_by_topic(**kwargs)

        for subscription in response.get("Subscriptions", []):
            if subscription.get("Endpoint") == email:
                return subscription.get("SubscriptionArn")

        token = response.get("NextToken")

        if not token:
            return None


def get_subscription(claims):
    email = claims.get("email", "")
    arn = _subscription_arn(email) if email else None

    return _respond(200, {
        "email": email,
        "subscribed": bool(arn) and arn != "PendingConfirmation",
        "pending": arn == "PendingConfirmation",
    })


def subscribe(claims):
    # The address comes from the verified token, never the request body. Reading
    # it from the body would let any caller subscribe someone else's inbox.
    email = claims.get("email", "")

    if not email:
        return _respond(400, {"message": "This account has no email address."})

    # Only activity aimed at this user reaches this subscription. _notify()
    # publishes the recipient id as a message attribute for exactly this.
    filter_policy = json.dumps({"recipient": [claims["sub"]]})

    existing = _subscription_arn(email)

    if existing == "PendingConfirmation":
        return _respond(202, {
            "subscribed": False,
            "pending": True,
            "message": "Check your inbox and confirm the subscription email.",
        })

    if existing:
        _sns.set_subscription_attributes(
            SubscriptionArn=existing,
            AttributeName="FilterPolicy",
            AttributeValue=filter_policy,
        )

        return _respond(200, {"subscribed": True, "pending": False})

    _sns.subscribe(
        TopicArn=SNS_TOPIC_ARN,
        Protocol="email",
        Endpoint=email,
        Attributes={"FilterPolicy": filter_policy},
    )

    # SNS sends its own confirmation email. The subscription delivers nothing
    # until that link is clicked, and it cannot be confirmed from here.
    return _respond(202, {
        "subscribed": False,
        "pending": True,
        "message": "Check your inbox and confirm the subscription email.",
    })


def unsubscribe(claims):
    email = claims.get("email", "")
    arn = _subscription_arn(email) if email else None

    # A pending subscription has no ARN to act on. It lapses on its own if the
    # confirmation link is never clicked.
    if not arn or arn == "PendingConfirmation":
        return _respond(200, {"subscribed": False, "pending": False})

    _sns.unsubscribe(SubscriptionArn=arn)

    return _respond(200, {"subscribed": False, "pending": False})


def _ensure_user(cursor, claims):
    """
    Likes and comments both carry a foreign key to users, so the row must exist
    before either insert. The Cognito PostConfirmation trigger normally creates
    it; a failed trigger, or an account deleted from Cognito and re-registered,
    otherwise leaves every like failing on the constraint.

    Returns None on success, or a message to show the user.
    """
    user_id = claims["sub"]

    cursor.execute("SELECT 1 FROM users WHERE user_id = %s", (user_id,))

    if cursor.fetchone():
        return None

    username = claims.get("cognito:username") or claims.get("email", "").split("@")[0]
    email = claims.get("email", "")

    try:
        cursor.execute(
            "INSERT INTO users (user_id, username, email) VALUES (%s, %s, %s)",
            (user_id, username, email),
        )
    except pymysql.err.IntegrityError as error:
        print(f"ERROR cannot create user row for {user_id}: {error}")
        return (
            "That email or username is already registered to another account. "
            "Sign in with the original account, or register with a different email."
        )

    return None


def _post_owner(cursor, post_id):
    cursor.execute("SELECT user_id FROM meme_posts WHERE post_id = %s", (post_id,))
    row = cursor.fetchone()
    return row["user_id"] if row else None


def _comments_for(cursor, post_id):
    cursor.execute(
        """
        SELECT c.comment_text, u.username
        FROM comments c
        JOIN users u ON u.user_id = c.user_id
        WHERE c.post_id = %s
        ORDER BY c.created_at ASC
        """,
        (post_id,),
    )
    return [{"username": r["username"], "text": r["comment_text"]} for r in cursor.fetchall()]


# --- handlers ----------------------------------------------------------

def toggle_like(cursor, event, claims):
    post_id = (event.get("pathParameters") or {}).get("postId")
    user_id = claims["sub"]

    owner = _post_owner(cursor, post_id)
    if owner is None:
        return _respond(404, {"message": "Post not found."})

    conflict = _ensure_user(cursor, claims)

    if conflict:
        return _respond(409, {"message": conflict})

    # Toggle: remove an existing like, otherwise add one. The UNIQUE key on
    # (post_id, user_id) means a double-click cannot inflate the count.
    cursor.execute(
        "DELETE FROM likes WHERE post_id = %s AND user_id = %s",
        (post_id, user_id),
    )
    liked = cursor.rowcount == 0

    if liked:
        cursor.execute(
            "INSERT INTO likes (post_id, user_id) VALUES (%s, %s)",
            (post_id, user_id),
        )

    cursor.execute("SELECT COUNT(*) AS total FROM likes WHERE post_id = %s", (post_id,))
    total = int(cursor.fetchone()["total"])

    # Don't notify people about their own activity.
    if liked and owner != user_id:
        _notify(owner, claims.get("cognito:username", "someone"), "like",
                f"{claims.get('cognito:username', 'someone')} liked your meme")

    return _respond(200, {"likes": total, "liked": liked})


def add_comment(cursor, event, claims):
    post_id = (event.get("pathParameters") or {}).get("postId")
    text = (_body(event).get("text") or "").strip()

    if not text or len(text) > MAX_COMMENT:
        return _respond(400, {"message": f"Comment must be 1 to {MAX_COMMENT} characters."})

    owner = _post_owner(cursor, post_id)
    if owner is None:
        return _respond(404, {"message": "Post not found."})

    conflict = _ensure_user(cursor, claims)

    if conflict:
        return _respond(409, {"message": conflict})

    cursor.execute(
        "INSERT INTO comments (post_id, user_id, comment_text) VALUES (%s, %s, %s)",
        (post_id, claims["sub"], text),
    )

    actor = claims.get("cognito:username", "someone")
    if owner != claims["sub"]:
        _notify(owner, actor, "comment", f"{actor} commented: {text[:60]}")

    return _respond(201, {"comments": _comments_for(cursor, post_id)})


def get_comments(cursor, event):
    post_id = (event.get("pathParameters") or {}).get("postId")
    return _respond(200, {"comments": _comments_for(cursor, post_id)})


# --- entry point -------------------------------------------------------

def lambda_handler(event, context):
    method = _method(event)
    resource = _route(event)

    if method == "OPTIONS":
        return _respond(200, {})

    claims = _claims(event)

    # Subscription management talks only to SNS, so it is answered before a
    # database connection is opened. Every method here needs an identity.
    if resource.endswith("/notifications/subscription"):
        if not claims:
            return _respond(401, {"message": "Sign in to continue."})

        if not _sns:
            return _respond(503, {"message": "Notifications are not configured."})

        try:
            if method == "GET":
                return get_subscription(claims)
            if method == "POST":
                return subscribe(claims)
            if method == "DELETE":
                return unsubscribe(claims)

            return _respond(404, {"message": f"No route for {method} {resource}."})

        except Exception as error:
            print(f"ERROR {method} {resource}: {type(error).__name__}: {error}")
            return _respond(500, {"message": "Could not update notification settings."})

    is_write = method == "POST"

    if is_write and not claims:
        return _respond(401, {"message": "Sign in to continue."})

    connection = None
    try:
        connection = _connect()
        with connection.cursor() as cursor:
            if resource.endswith("/likes") and method == "POST":
                result = toggle_like(cursor, event, claims)
            elif resource.endswith("/comments") and method == "POST":
                result = add_comment(cursor, event, claims)
            elif resource.endswith("/comments") and method == "GET":
                result = get_comments(cursor, event)
            else:
                return _respond(404, {"message": f"No route for {method} {resource}."})

        connection.commit()
        return result

    except Exception as error:
        if connection is not None:
            connection.rollback()
        print(f"ERROR {method} {resource}: {type(error).__name__}: {error}")
        return _respond(500, {"message": "Something went wrong. Please try again."})
