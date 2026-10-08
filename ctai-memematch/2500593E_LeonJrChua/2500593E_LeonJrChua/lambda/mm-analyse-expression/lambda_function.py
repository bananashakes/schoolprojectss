import base64
import json
import os
import uuid

import boto3
from botocore.exceptions import ClientError

UPLOAD_BUCKET = os.environ["UPLOAD_BUCKET"]
UPLOAD_PREFIX = os.environ.get("UPLOAD_PREFIX", "uploads").strip("/")
PUBLIC_BASE_URL = os.environ.get("PUBLIC_BASE_URL", "").rstrip("/")
CUSTOM_LABELS_ARN = os.environ.get("CUSTOM_LABELS_ARN", "").strip()
MIN_CONFIDENCE = float(os.environ.get("MIN_CONFIDENCE", "55"))
ALLOWED_ORIGIN = os.environ.get("ALLOWED_ORIGIN", "*")

# Label score at or above which a caption counts as flagged.
TOXICITY_THRESHOLD = float(os.environ.get("TOXICITY_THRESHOLD", "0.6"))

# Labels reported but never blocking. Profanity is common in meme captions; the
# remaining labels (HATE_SPEECH, INSULT, HARASSMENT_OR_ABUSE, SEXUAL,
# VIOLENCE_OR_THREAT, GRAPHIC) describe harm directed at a person and block.
IGNORED_TOXIC_LABELS = {
    label.strip().upper()
    for label in os.environ.get("ALLOWED_TOXIC_LABELS", "PROFANITY").split(",")
    if label.strip()
}

# Rekognition accepts at most 5MB of raw image bytes.
MAX_IMAGE_BYTES = 5 * 1024 * 1024

# A face smaller than this fraction of the frame gives the classifier too few
# pixels to work with.
MIN_FACE_RATIO = 0.10

rekognition = boto3.client("rekognition")
comprehend = boto3.client("comprehend")
s3 = boto3.client("s3")

# Maps Rekognition's stock emotions onto the expression classes the custom
# model is trained on. Used only when that model is unavailable. CALM is the
# stock label for a resting face, so it normalises to neutral.
EMOTION_TO_CLASS = {
    "HAPPY": "happy",
    "SURPRISED": "shocked",
    "CONFUSED": "thinking",
    "CALM": "neutral",
    "SAD": "sad",
    "FEAR": "sad",
    "ANGRY": "rage",
    "DISGUSTED": "rage",
    "UNKNOWN": "neutral",
}

# Used when Rekognition returns an emotion outside the map above. Must be a
# class present in the memes table, or no meme can be matched to it.
FALLBACK_CLASS = "neutral"

# Which classes read as positive or negative, for the caption vibe check.
CLASS_TONE = {
    "happy": "POSITIVE",
    "shocked": "NEUTRAL",
    "thinking": "NEUTRAL",
    "neutral": "NEUTRAL",
    "praying": "NEUTRAL",
    "sad": "NEGATIVE",
    "rage": "NEGATIVE",
}


# --- plumbing ----------------------------------------------------------

def _respond(status, body):
    return {
        "statusCode": status,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
            "Access-Control-Allow-Headers": "Content-Type,Authorization",
            "Access-Control-Allow-Methods": "POST,OPTIONS",
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
    The route template, e.g. "/analyse".

    REST API exposes it as `resource`. HTTP API embeds it in `routeKey`, as
    "POST /analyse".
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


def _decode_image(data_url):
    """Accept either a bare base64 string or a full `data:image/...;base64,` URL."""
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

    if len(raw) < 1024:
        return None, "That image looks empty."

    return raw, None


# --- step 1: quality gate ----------------------------------------------

def _quality_gate(image_bytes):
    """
    Reject images the classifier cannot do anything useful with, before
    spending a Custom Labels call or storing the file.

    Returns (face_detail, error_message).
    """
    response = rekognition.detect_faces(
        Image={"Bytes": image_bytes},
        Attributes=["ALL"],
    )

    faces = response.get("FaceDetails", [])

    if not faces:
        return None, "No face detected. Try better lighting and face the camera."

    if len(faces) > 1:
        return None, f"{len(faces)} faces detected. MemeMatch needs exactly one."

    face = faces[0]
    box = face.get("BoundingBox", {})

    if min(box.get("Width", 0), box.get("Height", 0)) < MIN_FACE_RATIO:
        return None, "Your face is too small in the frame. Move closer and retry."

    if face.get("Sunglasses", {}).get("Value"):
        return None, "Sunglasses hide the expression. Take them off and retry."

    if not face.get("EyesOpen", {}).get("Value", True) \
            and face["EyesOpen"].get("Confidence", 0) > 90:
        return None, "Your eyes are closed. Try again."

    return face, None


def _fallback_from_face(face):
    """Top stock emotion, mapped onto an expression class."""
    emotions = sorted(
        face.get("Emotions", []),
        key=lambda e: e.get("Confidence", 0),
        reverse=True,
    )

    # 0 when Rekognition returned no emotion to measure. A placeholder score
    # here would be indistinguishable from a real measurement.
    if not emotions:
        return FALLBACK_CLASS, 0.0, "UNKNOWN"

    top = emotions[0]
    emotion = top.get("Type", "UNKNOWN")

    return (
        EMOTION_TO_CLASS.get(emotion, FALLBACK_CLASS),
        round(float(top.get("Confidence", 0.0)), 2),
        emotion,
    )


# --- step 3: the trained classifier ------------------------------------

def _custom_labels(image_bytes):
    """
    Run the trained model. Returns (expression_class, confidence, note).
    A None class means the model is unavailable and the caller should fall back.
    """
    if not CUSTOM_LABELS_ARN:
        return None, None, "custom model not configured"

    try:
        response = rekognition.detect_custom_labels(
            ProjectVersionArn=CUSTOM_LABELS_ARN,
            Image={"Bytes": image_bytes},
            MinConfidence=MIN_CONFIDENCE,
            MaxResults=5,
        )
    except ClientError as error:
        code = error.response.get("Error", {}).get("Code", "")

        # ResourceNotReady means the model exists but is stopped, which is the
        # usual state: Custom Labels bills per hour while running.
        if code in ("ResourceNotReadyException", "ResourceNotFoundException"):
            print(f"INFO custom model unavailable ({code}), falling back")
            return None, None, f"model unavailable ({code})"

        raise

    labels = sorted(
        response.get("CustomLabels", []),
        key=lambda l: l.get("Confidence", 0),
        reverse=True,
    )

    if not labels:
        return None, None, "no label above the confidence threshold"

    top = labels[0]
    return top["Name"], round(float(top["Confidence"]), 2), ""


# --- handlers ----------------------------------------------------------

def analyse(event, claims):
    image_bytes, error = _decode_image(_body(event).get("imageBase64"))
    if error:
        return _respond(400, {"message": error})

    face, error = _quality_gate(image_bytes)
    if error:
        # Deliberately not stored. A rejected selfie never reaches S3.
        return _respond(422, {"message": error, "stage": "quality_gate"})

    key = f"{UPLOAD_PREFIX}/{claims['sub']}/{uuid.uuid4().hex}.jpg"
    s3.put_object(
        Bucket=UPLOAD_BUCKET,
        Key=key,
        Body=image_bytes,
        ContentType="image/jpeg",
    )
    image_url = f"{PUBLIC_BASE_URL}/{key}" if PUBLIC_BASE_URL else key

    expression_class, confidence, note = _custom_labels(image_bytes)
    source = "custom_labels"

    if expression_class is None:
        expression_class, confidence, stock_emotion = _fallback_from_face(face)
        source = "detect_faces"
    else:
        stock_emotion = None

    return _respond(200, {
        "expressionClass": expression_class,
        "confidenceScore": confidence,
        "classifierSource": source,
        "uploadedImageUrl": image_url,
        "fallbackNote": note or None,
        "stockEmotion": stock_emotion,
        # Surfaced so the UI can explain why an image was accepted.
        "faceQuality": {
            "brightness": round(float(face.get("Quality", {}).get("Brightness", 0)), 1),
            "sharpness": round(float(face.get("Quality", {}).get("Sharpness", 0)), 1),
            "smiling": bool(face.get("Smile", {}).get("Value")),
        },
    })


def _toxicity(caption):
    """
    Screen a caption with Comprehend's toxicity model.

    Sentiment is not a substitute: it measures tone, not harm. "I hate MySQL"
    scores strongly NEGATIVE and is harmless, while an insult can score
    POSITIVE. Toxicity returns per-label scores, so the filter acts on harm.

    Returns (is_toxic, flagged_labels, overall_score).
    """
    try:
        response = comprehend.detect_toxic_content(
            TextSegments=[{"Text": caption[:1000]}],
            LanguageCode="en",
        )
    except ClientError as error:
        # Toxicity detection is not offered in every region. A filter that
        # cannot run must never block posting.
        print(f"WARN toxicity check unavailable: {error}")
        return False, [], None

    results = response.get("ResultList") or []

    if not results:
        return False, [], None

    first = results[0]
    overall = float(first.get("Toxicity", 0))

    flagged = sorted(
        (
            {"name": label["Name"], "score": round(float(label["Score"]), 3)}
            for label in first.get("Labels", [])
            if float(label.get("Score", 0)) >= TOXICITY_THRESHOLD
        ),
        key=lambda label: label["score"],
        reverse=True,
    )

    blocking = [label for label in flagged if label["name"] not in IGNORED_TOXIC_LABELS]

    # Decided on labels alone, not the overall score. The aggregate rises with
    # profanity, so acting on it would block the captions PROFANITY exempts.
    return bool(blocking), blocking, round(overall, 3)


def sentiment(event, claims):
    """
    Toxicity first, which blocks publication. Then sentiment, which compares
    caption tone against the detected expression and reports a mismatch
    without blocking.
    """
    data = _body(event)
    caption = (data.get("caption") or "").strip()
    expression_class = data.get("expressionClass") or ""

    if not caption:
        return _respond(400, {"message": "No caption to check."})

    is_toxic, flagged, toxicity_score = _toxicity(caption)

    if is_toxic:
        names = ", ".join(
            label["name"].lower().replace("_", " ") for label in flagged
        ) or "harmful content"

        print(f"blocked caption, toxicity {toxicity_score}, labels {flagged}")

        return _respond(200, {
            "blocked": True,
            "toxic": True,
            "toxicityScore": toxicity_score,
            "toxicLabels": flagged,
            "message": f"That caption was flagged for {names}. Please reword it.",
        })

    result = comprehend.detect_sentiment(Text=caption[:4500], LanguageCode="en")
    detected = result["Sentiment"]
    scores = result["SentimentScore"]

    expected = CLASS_TONE.get(expression_class)

    # MIXED and NEUTRAL are never treated as a clash -- only a clear
    # positive/negative inversion counts as a mismatch.
    if expected is None or detected in ("NEUTRAL", "MIXED") or expected == "NEUTRAL":
        matches = None
    else:
        matches = detected == expected

    return _respond(200, {
        "blocked": False,
        "toxic": False,
        "toxicityScore": toxicity_score,
        "sentiment": detected,
        "confidence": round(max(scores.values()) * 100, 2),
        "expectedTone": expected,
        "matches": matches,
    })


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
        if resource == "/analyse" and method == "POST":
            return analyse(event, claims)
        if resource == "/sentiment" and method == "POST":
            return sentiment(event, claims)
        return _respond(404, {"message": f"No route for {method} {resource}."})

    except ClientError as error:
        code = error.response.get("Error", {}).get("Code", "")
        print(f"ERROR aws {code}: {error}")

        if code == "InvalidImageFormatException":
            return _respond(400, {"message": "That file is not a JPEG or PNG image."})
        if code == "ImageTooLargeException":
            return _respond(400, {"message": "That image is too large. Try a smaller one."})

        return _respond(502, {"message": "The recognition service is unavailable."})

    except Exception as error:
        print(f"ERROR {method} {resource}: {type(error).__name__}: {error}")
        return _respond(500, {"message": "Something went wrong. Please try again."})
