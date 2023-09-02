import boto3

def lambda_handler(event, context):
    sns_client = boto3.client('sns')
    message = "A QuickSight Report has been generated in the final bucket!"
    
    response = sns_client.publish(
        TopicArn='YOUR_SNS_TOPIC_ARN',
        Message=message,
        Subject='QuickSight Report Notification',
    )
    
    print(response)