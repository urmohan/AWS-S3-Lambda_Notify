import boto3
import json

def lambda_handler(event, context):
    bkt_name = event['Records'][0]['s3']['bucket']['name']
    obj_key = event['Records'][0]['s3']['object']['key']

    print(f"File '{object_key} was uploaded to S3 '{bucket_name}' Bucket")
    sns_client = boto3.client('sns')
    topic_sns = 'arn::aws:sns:us-east-1:<account-id>:s3-lambda-sns'
    sns_client.publish(
        topicArn=topic_sns,
        Subject='S3 Object Created',
        Message=f"File '{object_key} was uploaded to S3 '{bucket_name}' Bucket"
    )

    return {
        'statuscode': 200,
        'body': json.dumps('Lamba function executed successfully')
    }