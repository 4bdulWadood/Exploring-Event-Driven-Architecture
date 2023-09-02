import logging
import boto3
import os
import json
import csv
from io import StringIO

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    logger.info(f"event: {event}")
    logger.info(f"context: {context}")

    # Extract the S3 bucket and key from the event
    source_bucket = event["Records"][0]["s3"]["bucket"]["name"]
    key = event["Records"][0]["s3"]["object"]["key"]

    # Destination bucket
    destination_bucket = "destinationbucket564333"

    # Create an S3 client
    s3_client = boto3.client('s3')

    # Load and parse the JSON object from S3
    response = s3_client.get_object(Bucket=source_bucket, Key=key)
    json_data = json.loads(response['Body'].read())

    # Convert JSON to CSV
    csv_data = StringIO()
    csv_writer = csv.writer(csv_data)
    csv_writer.writerow(["date", "product", "sales"])  # Write CSV header

    for item in json_data:
        csv_writer.writerow([item["date"], item["product"], item["sales"]])

    # Adjust the key for the CSV file in the destination bucket
    csv_key = key.replace(".json", ".csv")

    # Upload the CSV data to the destination bucket
    s3_client.put_object(Bucket=destination_bucket, Key=csv_key, Body=csv_data.getvalue())

    return {
        'statusCode': 200,
        'body': 'CSV conversion and upload completed.'
    }
