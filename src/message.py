import boto3


def lambda_handler(event, context):
    # Initialize an SNS client
    sns_client = boto3.client('sns', region_name='us-east-1')  # Replace 'your-aws-region' with your AWS region
    
    sts_client = boto3.client('sts')
    response = sts_client.get_caller_identity()
    account_id = response['Account']

    # Specify the ARN of the SNS topic you want to publish to
    topic_arn = f'arn:aws:sns:us-east-1:{account_id}:quicksight_report_topic'  # Replace with your actual SNS topic ARN

    # Message content
    message = "The QuickSight Report has been successfully uploaded into the S3 Bucket!"

    try:
        # Publish the message to the SNS topic
        response = sns_client.publish(
            TopicArn=topic_arn,
            Message=message
        )
        
        # Check if the message was successfully published
        if 'MessageId' in response:
            print(f"Message published with MessageId: {response['MessageId']}")
        else:
            print("Failed to publish the message.")

    except Exception as e:
        print(f"An error occurred: {str(e)}")