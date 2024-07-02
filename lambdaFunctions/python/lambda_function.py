import json

def lambda_handler(event, context):
    return {
        'statusCode': 200,
        'body': json.dumps("I sure hope there isn't any chaos around here!")
    }
