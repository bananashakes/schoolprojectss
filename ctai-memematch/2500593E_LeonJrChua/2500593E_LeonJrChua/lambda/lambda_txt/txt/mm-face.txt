import base64
import json
import os

import boto3
from botocore.exceptions import ClientError

FACE_COLLECTION_ID = os.environ["FACE_COLLECTION_ID"]
SIMILARITY_THRESHOLD = float(os.environ.get("SIMILARITY_THRESHOLD", "85"))
ALLOWED_ORIGIN = os.environ.get("ALLOWED_ORIGIN", "*")

MAX_IMAGE_BYTES = 5 * 1024 * 1024

rekognition = boto3.client("rekognition")


# --- plumbing ----------------------------------------------------------

def _respond(status, body):
    return {
        "statusCode": status,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
            "Access-Control-Allow-Headers": "Content-Type,Authorization",
            "Access-Control-Allow-Methods": "GET,POST,DELETE,OPTIONS",
        },
        "body": json.dumps(body),
    }


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
    The route template, e.g. "/face/enrol".

    REST API exposes it as `resource`. HTTP API embeds it in `routeKey`, as
    "POST /face/enrol".
    """
    if event.get("resource"):
        return event["resource"]

    route_key = event.get("routeKey") or ""

    if " " in route_key:
        return route_key.split(" ", 1)[1]

    return ((event.get("requestContext") or {}).get("http") or {}).get("path", "")


def _decode_image(event):
    try:
        data_url = json.loads(event.get("body") or "{}").get("imageBase64")
    except json.JSONDecodeError:
        return None, "That request could not be read."

    if not data_url:
        return None, "No image was provided."

    if "," in data_url and data_url.strip().startswith("data:"):
        data_url = data_url.split(",", 1)[1]

    try:
        raw = base64.b64decode(data_url, validate=True)
    except Exception:
        return None, "That image could not be read."

    if len(raw) > MAX_IMAGE_BYTES:
        return None, "That image is too large. Please use one under 5MB."

    return raw, None


# --- handlers ----------------------------------------------------------

def enrol(event, claims):
    image_bytes, error = _decode_image(event)
    if error:
        return _respond(400, {"message": error})

    user_id = claims["sub"]

    # Replace any previous enrolment so a user can re-enrol with a better photo
    # and does not accumulate stale vectors.
    _delete_existing(user_id)

    response = rekognition.index_faces(
        CollectionId=FACE_COLLECTION_ID,
        Image={"Bytes": image_bytes},
        # Ties the stored vector to the Cognito identity. Sub is a UUID, which
        # satisfies the [a-zA-Z0-9_.\-:]+ constraint on this field.
        ExternalImageId=user_id,
        MaxFaces=1,
        QualityFilter="AUTO",
        DetectionAttributes=[],
    )

    records = response.get("FaceRecords", [])

    if not records:
        unindexed = response.get("UnindexedFaces", [])
        reasons = unindexed[0].get("Reasons", []) if unindexed else []

        if "EXCEEDS_MAX_FACES" in reasons:
            message = "More than one face in that photo. Enrol on your own."
        elif reasons:
            message = "That photo was too low quality. Try better lighting, facing the camera."
        else:
            message = "No face detected. Try again facing the camera."

        return _respond(422, {"message": message, "reasons": reasons})

    face = records[0]["Face"]

    return _respond(201, {
        "enrolled": True,
        "faceId": face["FaceId"],
        "confidence": round(float(face.get("Confidence", 0)), 2),
    })


def verify(event, claims):
    image_bytes, error = _decode_image(event)
    if error:
        return _respond(400, {"message": error})

    user_id = claims["sub"]

    try:
        response = rekognition.search_faces_by_image(
            CollectionId=FACE_COLLECTION_ID,
            Image={"Bytes": image_bytes},
            FaceMatchThreshold=SIMILARITY_THRESHOLD,
            MaxFaces=1,
        )
    except ClientError as error:
        # Rekognition raises rather than returning an empty list when the image
        # contains no face at all.
        if error.response.get("Error", {}).get("Code") == "InvalidParameterException":
            return _respond(422, {
                "verified": False,
                "message": "No face detected in that image.",
            })
        raise

    matches = response.get("FaceMatches", [])

    if not matches:
        return _respond(200, {
            "verified": False,
            "message": "That does not look like your enrolled face.",
        })

    top = matches[0]
    matched_user = top["Face"].get("ExternalImageId")
    similarity = round(float(top.get("Similarity", 0)), 2)

    # A match against another user's enrolled face is still "not verified" here,
    # and the response never identifies whose face it was.
    verified = matched_user == user_id

    return _respond(200, {
        "verified": verified,
        "similarity": similarity if verified else None,
        "message": "Verified" if verified else "That does not look like your enrolled face.",
    })


def unenrol(event, claims):
    """
    Withdraw an enrolment: deletes this user's stored face vectors.

    Posting still works afterwards, just without the verified badge.
    """
    removed = _delete_existing(claims["sub"])

    return _respond(200, {"enrolled": False, "removed": removed})


def status(event, claims):
    """Has this user enrolled? Drives the badge on the profile page."""
    user_id = claims["sub"]
    enrolled = _find_face_ids(user_id)

    return _respond(200, {
        "enrolled": bool(enrolled),
        "faceCount": len(enrolled),
    })


# --- collection helpers ------------------------------------------------

def _find_face_ids(user_id):
    """
    Every FaceId in the collection belonging to this user.

    ListFaces has no server-side filter on ExternalImageId, so this pages
    through and filters locally. Adequate at this collection size; a larger
    deployment would store the mapping in the database.
    """
    face_ids = []
    token = None

    while True:
        kwargs = {"CollectionId": FACE_COLLECTION_ID, "MaxResults": 500}
        if token:
            kwargs["NextToken"] = token

        response = rekognition.list_faces(**kwargs)

        for face in response.get("Faces", []):
            if face.get("ExternalImageId") == user_id:
                face_ids.append(face["FaceId"])

        token = response.get("NextToken")
        if not token:
            return face_ids


def _delete_existing(user_id):
    """Remove every face this user has enrolled. Returns how many were deleted."""
    face_ids = _find_face_ids(user_id)

    if not face_ids:
        return 0

    rekognition.delete_faces(
        CollectionId=FACE_COLLECTION_ID,
        FaceIds=face_ids,
    )
    print(f"removed {len(face_ids)} enrolment(s) for {user_id}")

    return len(face_ids)


# --- entry point -------------------------------------------------------

def lambda_handler(event, context):
    method = _method(event)
    resource = _route(event)

    if method == "OPTIONS":
        return _respond(200, {})

    claims = _claims(event)
    if not claims:
        return _respond(401, {"message": "Sign in to continue."})

    try:
        if resource == "/face/enrol" and method == "POST":
            return enrol(event, claims)
        if resource == "/face/enrol" and method == "DELETE":
            return unenrol(event, claims)
        if resource == "/face/verify" and method == "POST":
            return verify(event, claims)
        if resource == "/face/status" and method == "GET":
            return status(event, claims)
        return _respond(404, {"message": f"No route for {method} {resource}."})

    except ClientError as error:
        code = error.response.get("Error", {}).get("Code", "")
        print(f"ERROR aws {code}: {error}")

        if code == "ResourceNotFoundException":
            return _respond(500, {
                "message": "Face collection not found. Check FACE_COLLECTION_ID.",
            })
        if code == "InvalidImageFormatException":
            return _respond(400, {"message": "That file is not a JPEG or PNG image."})

        return _respond(502, {"message": "The face service is unavailable."})

    except Exception as error:
        print(f"ERROR {method} {resource}: {type(error).__name__}: {error}")
        return _respond(500, {"message": "Something went wrong. Please try again."})
