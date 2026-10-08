import json
import os

import boto3
from botocore.exceptions import ClientError

COLLECTION_ID = os.environ.get("FACE_COLLECTION_ID", "memematch-faces")


def lambda_handler(event, context):
    rekognition = boto3.client("rekognition")
    result = {"collectionId": COLLECTION_ID}

    try:
        response = rekognition.create_collection(CollectionId=COLLECTION_ID)
        result["created"] = True
        result["collectionArn"] = response.get("CollectionArn")

    except ClientError as error:
        code = error.response.get("Error", {}).get("Code", "")

        if code != "ResourceAlreadyExistsException":
            # Usually the execution role lacking Rekognition permissions.
            print(f"ERROR could not create collection: {code}: {error}")
            raise

        result["created"] = False
        result["note"] = "Collection already existed, nothing changed."

    # Read back, so the output reflects the collection's actual state.
    described = rekognition.describe_collection(CollectionId=COLLECTION_ID)

    result["faceCount"] = described.get("FaceCount", 0)
    result["collectionArn"] = result.get("collectionArn") or described.get("CollectionARN")

    print(json.dumps(result, indent=2, default=str))

    return result
