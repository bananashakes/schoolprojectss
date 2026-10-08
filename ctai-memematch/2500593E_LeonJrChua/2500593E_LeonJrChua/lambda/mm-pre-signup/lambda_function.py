import os

import boto3

USER_POOL_ID = os.environ["USER_POOL_ID"]

cognito = boto3.client("cognito-idp")


def lambda_handler(event, context):
    attributes = event.get("request", {}).get("userAttributes", {})
    email = (attributes.get("email") or "").strip().lower()

    if not email:
        return event

    # Double quotes terminate the filter expression, so an address containing
    # one would let a crafted value change the query's meaning.
    if '"' in email:
        raise Exception("That email address is not valid.")

    response = cognito.list_users(
        UserPoolId=USER_POOL_ID,
        Filter=f'email = "{email}"',
        Limit=1,
    )

    existing = response.get("Users", [])

    if existing:
        print(f"blocked duplicate sign-up for {email}")
        # Cognito surfaces this text to the client and cancels the sign-up.
        raise Exception("An account with that email already exists. Try logging in.")

    return event
