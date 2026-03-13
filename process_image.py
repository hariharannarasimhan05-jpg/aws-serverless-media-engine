import boto3
import json
import os

# Initialize AWS clients
s3 = boto3.client('s3')
rekognition = boto3.client('rekognition')
dynamodb = boto3.resource('dynamodb')
sns = boto3.client('sns')

def lambda_handler(event, context):
    # 1. Get bucket and file name from the S3 event
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']
    
    print(f"Processing image: {key} from bucket: {bucket}")

    # 2. Call AWS Rekognition to detect labels
    response = rekognition.detect_labels(
        Image={'S3Object': {'Bucket': bucket, 'Name': key}},
        MaxLabels=5
    )
    
    labels = [label['Name'] for label in response['Labels']]
    print(f"Detected labels: {labels}")

    # 3. Save metadata to DynamoDB
    table = dynamodb.Table('HariImageLabels')
    table.put_item(
        Item={
            'ImageID': key,
            'Labels': labels,
            'Bucket': bucket
        }
    )

    # 4. Send SNS Notification
    sns.publish(
        TopicArn=os.environ['SNS_TOPIC_ARN'],
        Message=f"Success! Hari's AI found these objects in {key}: {', '.join(labels)}",
        Subject="Image Processing Complete"
    )

    return {
        'statusCode': 200,
        'body': json.dumps('Processing Complete!')
    }