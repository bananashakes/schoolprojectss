import json
import os

import boto3
import pymysql

DB_SECRET_NAME = os.environ["DB_SECRET_NAME"]
DB_NAME = os.environ.get("DB_NAME", "memematch")

_secret = None
_connection = None


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


def lambda_handler(event, context):
    attributes = event.get("request", {}).get("userAttributes", {})

    user_id = attributes.get("sub")
    email = attributes.get("email", "")
    username = event.get("userName") or email.split("@")[0]

    if not user_id:
        print("WARN no sub in userAttributes, skipping database insert")
        return event

    connection = None
    try:
        connection = _connect()
        with connection.cursor() as cursor:
            # ON DUPLICATE KEY keeps this safe to run twice. Cognito can retry a
            # trigger, and a user who deletes and re-registers reuses the email.
            cursor.execute(
                """
                INSERT INTO users (user_id, username, email)
                VALUES (%s, %s, %s)
                ON DUPLICATE KEY UPDATE user_id = user_id
                """,
                (user_id, username, email),
            )
        connection.commit()
        print(f"registered user {username} ({user_id})")

    except Exception as error:
        if connection is not None:
            connection.rollback()
        # Swallow the failure on purpose. Raising here would block the sign-up
        # entirely; mm-posts-crud calls _ensure_user() as a safety net, so the
        # account still works if this row is missing.
        print(f"ERROR could not insert user {user_id}: {type(error).__name__}: {error}")

    return event
