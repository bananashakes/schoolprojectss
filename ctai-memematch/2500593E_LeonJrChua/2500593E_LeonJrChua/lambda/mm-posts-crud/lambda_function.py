import decimal
import json
import os
from datetime import date, datetime

import boto3
import pymysql

DB_SECRET_NAME = os.environ["DB_SECRET_NAME"]
DB_NAME = os.environ.get("DB_NAME", "memematch")
ALLOWED_ORIGIN = os.environ.get("ALLOWED_ORIGIN", "*")

MAX_CAPTION = 160
PAGE_SIZE = 30
RECENT_COMMENTS = 3

# Mirrors the classifier_source ENUM. A value outside this set would fail the
# insert, so it is rejected with a clear message instead.
CLASSIFIER_SOURCES = ("custom_labels", "detect_faces")

# Cached across warm invocations, so Secrets Manager is called on cold start only.
_secret = None
_connection = None


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
            "Access-Control-Allow-Methods": "GET,POST,PATCH,DELETE,OPTIONS",
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
    """Reuse the warm connection, but ping first -- RDS drops idle sockets."""
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
    The route template, e.g. "/posts/{postId}".

    REST API exposes it as `resource`. HTTP API embeds it in `routeKey`, as
    "PATCH /posts/{postId}".
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


def _ensure_user(cursor, claims):
    """
    Ensure a users row exists for this Cognito identity, in case the
    PostConfirmation trigger did not create one. Every post carries a foreign
    key to users, so without a row the account can sign in but cannot post.

    Returns None on success, or a message to show the user.

    Deliberately not ON DUPLICATE KEY UPDATE: users has unique keys on username
    and email as well as the primary key, so a second Cognito account sharing an
    email collides on uq_users_email and the upsert would update that other
    user's row while creating none here, failing the next foreign key.
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
        # The username or email already belongs to a different Cognito account.
        print(f"ERROR cannot create user row for {user_id}: {error}")
        return (
            "That email or username is already registered to another account. "
            "Sign in with the original account, or register with a different email."
        )

    return None


# --- shaping -----------------------------------------------------------

def _shape_post(row, comments_by_post):
    """Map a database row onto the object shape renderPostCard() consumes."""
    return {
        "id": str(row["post_id"]),
        "userId": row["user_id"],
        "username": row["username"],
        "uploadedImageUrl": row["uploaded_image_url"],
        "matchedMemeUrl": row["meme_image_url"],
        "matchedMemeName": row["meme_name"],
        "detectedEmotion": row["detected_emotion"],
        "confidenceScore": float(row["confidence_score"]),
        "classifierSource": row["classifier_source"],
        "faceVerified": bool(row["face_verified"]),
        "caption": row["caption"] or "",
        "captionSentiment": row["caption_sentiment"],
        "sentimentMatches": (
            None if row["sentiment_matches"] is None else bool(row["sentiment_matches"])
        ),
        "isRemix": bool(row["is_remix"]),
        "templateUrl": row["template_url"],
        "topText": row["top_text"],
        "bottomText": row["bottom_text"],
        "likes": int(row["likes"]),
        "liked": bool(row["liked"]),
        "comments": comments_by_post.get(row["post_id"], []),
        "createdAt": row["created_at"],
    }


def _fetch_comments(cursor, post_ids):
    if not post_ids:
        return {}

    placeholders = ",".join(["%s"] * len(post_ids))
    cursor.execute(
        f"""
        SELECT c.post_id, c.comment_text, u.username
        FROM comments c
        JOIN users u ON u.user_id = c.user_id
        WHERE c.post_id IN ({placeholders})
        ORDER BY c.created_at ASC
        """,
        tuple(post_ids),
    )

    grouped = {}
    for row in cursor.fetchall():
        bucket = grouped.setdefault(row["post_id"], [])
        bucket.append({"username": row["username"], "text": row["comment_text"]})

    # renderPostCard only shows the last few, so trim here rather than shipping
    # every comment on every feed load.
    return {pid: items[-RECENT_COMMENTS:] for pid, items in grouped.items()}


# --- READ --------------------------------------------------------------

def get_posts(cursor, event, claims):
    params = event.get("queryStringParameters") or {}
    viewer = claims["sub"] if claims else ""

    where, values = [], [viewer]

    if params.get("userId"):
        where.append("p.user_id = %s")
        values.append(params["userId"])

    if params.get("emotion"):
        where.append("p.detected_emotion = %s")
        values.append(params["emotion"])

    clause = f"WHERE {' AND '.join(where)}" if where else ""

    cursor.execute(
        f"""
        SELECT p.*, u.username,
               m.meme_name, m.meme_image_url,
               (SELECT COUNT(*) FROM likes l WHERE l.post_id = p.post_id) AS likes,
               EXISTS(SELECT 1 FROM likes l2
                      WHERE l2.post_id = p.post_id AND l2.user_id = %s) AS liked
        FROM meme_posts p
        JOIN users u ON u.user_id = p.user_id
        LEFT JOIN memes m ON m.meme_id = p.matched_meme_id
        {clause}
        ORDER BY p.created_at DESC
        LIMIT {PAGE_SIZE}
        """,
        tuple(values),
    )

    rows = cursor.fetchall()
    comments = _fetch_comments(cursor, [r["post_id"] for r in rows])

    return _respond(200, {"posts": [_shape_post(r, comments) for r in rows]})


def get_memes(cursor, event):
    params = event.get("queryStringParameters") or {}
    expression_class = params.get("expressionClass")

    if expression_class:
        # ORDER BY RAND() drives the "reroll another match" button: the same
        # expression can return a different meme each time.
        cursor.execute(
            """
            SELECT meme_id, meme_name, meme_image_url, expression_class, quote
            FROM memes
            WHERE expression_class = %s AND active_status = 1
            ORDER BY RAND()
            """,
            (expression_class,),
        )
    else:
        cursor.execute(
            """
            SELECT meme_id, meme_name, meme_image_url, expression_class, quote
            FROM memes
            WHERE active_status = 1
            ORDER BY expression_class
            """
        )

    memes = [
        {
            "id": row["meme_id"],
            "name": row["meme_name"],
            "imageUrl": row["meme_image_url"],
            "expressionClass": row["expression_class"],
            "quote": row["quote"],
        }
        for row in cursor.fetchall()
    ]

    return _respond(200, {"memes": memes})


# --- CREATE ------------------------------------------------------------

def create_post(cursor, event, claims):
    data = _body(event)
    caption = (data.get("caption") or "").strip()

    if len(caption) > MAX_CAPTION:
        return _respond(400, {"message": f"Caption must be {MAX_CAPTION} characters or fewer."})

    if not data.get("detectedEmotion"):
        return _respond(400, {"message": "detectedEmotion is required."})

    # Absent falls back to the column default; an unrecognised value is a bug in
    # the caller and is refused rather than recorded as a real classifier.
    classifier_source = data.get("classifierSource") or "custom_labels"

    if classifier_source not in CLASSIFIER_SOURCES:
        return _respond(400, {"message": "classifierSource is not a known value."})

    conflict = _ensure_user(cursor, claims)

    if conflict:
        # Return the real reason rather than letting the next statement fail its
        # foreign key, which surfaces as an opaque 500.
        return _respond(409, {"message": conflict})

    cursor.execute(
        """
        INSERT INTO meme_posts (
            user_id, uploaded_image_url, matched_meme_id, detected_emotion,
            confidence_score, classifier_source, face_verified, caption,
            caption_sentiment, sentiment_matches,
            is_remix, template_url, top_text, bottom_text
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """,
        (
            claims["sub"],
            data.get("uploadedImageUrl"),
            data.get("matchedMemeId"),
            data["detectedEmotion"],
            float(data.get("confidenceScore") or 0),
            classifier_source,
            1 if data.get("faceVerified") else 0,
            caption,
            data.get("captionSentiment"),
            None if data.get("sentimentMatches") is None else int(bool(data["sentimentMatches"])),
            1 if data.get("isRemix") else 0,
            data.get("templateUrl"),
            data.get("topText"),
            data.get("bottomText"),
        ),
    )

    return _respond(201, {"success": True, "postId": str(cursor.lastrowid)})


# --- UPDATE ------------------------------------------------------------

def update_post(cursor, event, claims):
    post_id = (event.get("pathParameters") or {}).get("postId")
    caption = (_body(event).get("caption") or "").strip()

    if not caption or len(caption) > MAX_CAPTION:
        return _respond(400, {"message": f"Caption must be 1 to {MAX_CAPTION} characters."})

    # The user_id in the WHERE clause is the ownership check: a post belonging
    # to another user matches no row, so rowcount stays 0.
    cursor.execute(
        "UPDATE meme_posts SET caption = %s WHERE post_id = %s AND user_id = %s",
        (caption, post_id, claims["sub"]),
    )

    if cursor.rowcount == 0:
        return _respond(403, {"message": "You can only edit your own posts."})

    return _respond(200, {"success": True, "postId": post_id, "caption": caption})


# --- DELETE ------------------------------------------------------------

def delete_post(cursor, event, claims):
    post_id = (event.get("pathParameters") or {}).get("postId")

    # Likes and comments disappear with the post via ON DELETE CASCADE.
    cursor.execute(
        "DELETE FROM meme_posts WHERE post_id = %s AND user_id = %s",
        (post_id, claims["sub"]),
    )

    if cursor.rowcount == 0:
        return _respond(403, {"message": "You can only delete your own posts."})

    return _respond(200, {"success": True, "postId": post_id})


# --- entry point -------------------------------------------------------

ROUTES = {
    ("GET", "/posts"): "read",
    ("GET", "/memes"): "read",
    ("POST", "/posts"): "write",
    ("PATCH", "/posts/{postId}"): "write",
    ("DELETE", "/posts/{postId}"): "write",
}


def lambda_handler(event, context):
    method = _method(event)
    resource = _route(event)

    if method == "OPTIONS":
        return _respond(200, {})

    access = ROUTES.get((method, resource))
    if access is None:
        return _respond(404, {"message": f"No route for {method} {resource}."})

    claims = _claims(event)
    if access == "write" and not claims:
        return _respond(401, {"message": "Sign in to continue."})

    connection = None
    try:
        connection = _connect()
        with connection.cursor() as cursor:
            if method == "GET" and resource == "/posts":
                result = get_posts(cursor, event, claims)
            elif method == "GET":
                result = get_memes(cursor, event)
            elif method == "POST":
                result = create_post(cursor, event, claims)
            elif method == "PATCH":
                result = update_post(cursor, event, claims)
            else:
                result = delete_post(cursor, event, claims)

        connection.commit()
        return result

    except Exception as error:
        if connection is not None:
            connection.rollback()
        # Full detail to CloudWatch, a generic message to the browser -- an
        # error page should never leak the schema or the RDS endpoint.
        print(f"ERROR {method} {resource}: {type(error).__name__}: {error}")
        return _respond(500, {"message": "Something went wrong. Please try again."})
