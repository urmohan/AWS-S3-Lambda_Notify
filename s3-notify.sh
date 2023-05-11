#!/bin/bash

set -e

aws_account_id=$(aws sts get-caller-identity --query 'Account' --output text)
echo "AWS Account ID: $aws_account_id"

aws_region="us-east-1"
bucket_name="mohan-bucket-101"
lambda_func_name="s3-lambda-function"
role_name="s3-lambda-sns"
email_id="devops77781@gmail.com"

# Create IAM Role for S3 Lambda function
role_response=$(aws iam create-role --role-name s3-lambda-sns --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
        "Action": "sts:AssumeRole",
        "Effect": "Allow",
        "Principal": {
            "Service": [
                "lambda.amazonaws.com",
                "s3.amazonaws.com",
                "sns.amazonaws.com"
            ]
        }
    }]
}')

# Role ARN from JSON Response
role_arn=$(echo "$role_response" | jq -r '.Role.Arn')
echo "Role ARN: $role_arn"

# Attach Permissions to the Roles - Lambda & SNS
aws iam attach-role-policy --role-name $role_name --policy-arn arn:aws:iam::aws:policy/AWSLambda_FullAccess
aws iam attach-role-policy --role-name $role_name --policy-arn arn:aws:iam::aws:policy/AmazonSNSFullAccess

bucket_create=$(aws s3api create-bucket --bucket "$bucket_name" --region "$aws_region")
echo "Bucket creation: $bucket_create"

#Upload sample file to S3 
aws s3 cp ./SampleFile.txt s3://"$bucket_name"/SampleFile.txt

#Upload Lambda function with requirements in zip and create Lambda function
zip -r lambda-function.zip ./lambda-func
sleep 5
aws lambda create-function \
    --region "$aws_region" \
    --function-name "$lambda_func_name" \
    --runtime "python3.8" \
    --handler "lambda-func/lambda-function.lambda_handler" \
    --memory-size 128 \
    --timeout 30 \
    --role "arn:aws:iam::$aws_account_id:role/$role_name" \
    --zip-file "fileb://./lambda-function.zip"

aws lambda add-permission \
    --region "$aws_region" \
    --function-name "$lambda_func_name" \
    --statement-id "s3-lambda-sns" \
    --action "lambda:InvokeFunction" \
    --principal s3.amazonaws.com \
    --source-arn "arn:aws:s3:::$bucket_name"

LambdaFunctionArn="arn:aws:lambda:$aws_region:$aws_account_id:function:s3-lambda-function"
aws s3api put-bucket-notification-configuration \
    --region "$aws_region" \
    --bucket "$bucket_name" \
    --notification-configuration '{
      "LambdaFunctionConfigurations": [{
            "LambdaFunctionArn": "'"$LambdaFunctionArn"'",
            "Events": ["s3:ObjectCreated:*"]
        }]
    }'


topic_arn=$(aws sns create-topic --name s3-lambda-sns --region "$aws_region" --output json | jq -r '.TopicArn')
echo "SNS Topic ARN: $topic_arn"

aws sns subscribe \
    --region "$aws_region" \
    --topic-arn "$topic_arn" \
    --protocol email \
    --notification-endpoint "$email_id"
    
aws sns publish \
    --region "$aws_region" \
    --topic-arn "$topic_arn" \
    --subject "A new file created in bucket" \
    --message "file created succussfully from lambda function"
       
