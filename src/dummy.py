import boto3
import json
import os
import csv
from botocore.exceptions import ClientError

# Initialize AWS clients
quicksight = boto3.client('quicksight', region_name='us-east-1')
s3 = boto3.client('s3')
sts = boto3.client('sts')

# AWS Account ID
account_id = sts.get_caller_identity()['Account']

def create_quicksight_report(csv_content):
    try:
        # Define the dataset configuration
        dataset_config = {
            "DataSetId": "your-dataset-id",
            "Name": "MyDataset",
            "PhysicalTableMap": {
                "MyPhysicalTable": {
                    "CustomSql": {},
                    "S3Source": {
                        "DataSourceArn": f"arn:aws:s3:::finalbucket564333/folder/file.csv",
                        "InputColumns": [
                            {"Name": "date", "Type": "STRING"},
                            {"Name": "product", "Type": "STRING"},
                            {"Name": "sales", "Type": "DECIMAL(10,2)"}
                        ]
                    },
                }
            },
            "LogicalTableMap": {
                "MyLogicalTable": {
                    "Alias": "MyLogicalTableAlias",
                    "DataTransforms": [],
                    "Source": "MyPhysicalTable",
                }
            },
        }

        # Create or update the dataset
        response = quicksight.create_data_set(
        AwsAccountId=account_id,
        DataSetId="your-dataset-id",
        Name="MyDataset",
        PhysicalTableMap={
            "DatasetPlaceholder": {  # Replace "MyPhysicalTable" with "DatasetPlaceholder"
                "CustomSql": "",
                "S3Source": {
                    "DataSourceArn": f"arn:aws:s3:::finalbucket564333/folder/file.csv",
                    "InputColumns": [
                        {"Name": "date", "Type": "STRING"},
                        {"Name": "product", "Type": "STRING"},
                        {"Name": "sales", "Type": "DECIMAL(10,2)"}
                    ]
                },
            }
        },
        
        LogicalTableMap={
            "MyLogicalTableAlias": {  # Replace "MyLogicalTable" with "MyLogicalTableAlias"
                "Alias": "MyLogicalTableAlias",
                "DataTransforms": [],
                "Source": {"PhysicalTableId": "DatasetPlaceholder"},  # Add source as a dictionary
            }
        },
        ImportMode='DIRECT',  # Specify the import mode
        )

        # Create a report
        response = quicksight.create_analysis(
            AwsAccountId=account_id,
            AnalysisId="your-analysis-id",
            Name="MyReport",
            SourceEntity={
                "SourceAnalysis": {
                    "Arn": f"arn:aws:quicksight:us-east-1:{account_id}:analysis/MyAnalysis",
                },
            },
        )

        # Add a report filter
        response = quicksight.update_analysis_permissions(
            AwsAccountId=account_id,
            AnalysisId="your-analysis-id",
            Grants=[
                {
                    "Principal": f"arn:aws:quicksight:us-east-1:{account_id}:user/default/{quicksight.get_user()['UserName']}",
                    "Actions": ["quicksight:UpdateAnalysisPermissions"],
                },
            ],
        )

        # Create a dashboard
        response = quicksight.create_dashboard(
            AwsAccountId=account_id,
            DashboardId="your-dashboard-id",
            Name="MyDashboard",
            SourceEntity={
                "SourceTemplate": {
                    "DataSetReferences": [
                        {
                            "DataSetArn": f"arn:aws:quicksight:us-east-1:{account_id}:dataset/{dataset_config['DataSetId']}",
                            "DataSetPlaceholder": "MyDataset",
                        },
                    ],
                    "Arn": f"arn:aws:quicksight:us-east-1:{account_id}:template/{response['TemplateId']}",
                },
            },
        )

        # Publish the dashboard
        response = quicksight.update_dashboard_permissions(
            AwsAccountId=account_id,
            DashboardId="your-dashboard-id",
            GrantPermissions=[
                {
                    "Principal": f"arn:aws:quicksight:us-east-1:{account_id}:user/default/{quicksight.get_user()['UserName']}",
                    "Actions": ["quicksight:DescribeDashboard"],
                },
            ],
        )

        return "Success"
    except ClientError as e:
        print(f'Error: {e}')
        return 'Error'

def lambda_handler(event, context):
    try:
        # Extract bucket and object information from the S3 event
        s3_event = event['Records'][0]['s3']
        source_bucket = s3_event['bucket']['name']
        object_key = s3_event['object']['key']

        # Read CSV data from S3
        csv_object = s3.get_object(Bucket=source_bucket, Key=object_key)
        csv_content = csv_object['Body'].read().decode('utf-8')

        # Parse CSV data
        csv_data = csv.reader(csv_content.splitlines())
        header = next(csv_data)  # Read the header row

        # Specify the target bucket (FinalBucket)
        final_bucket = 'finalbucket564333'

        # Generate a unique object key for the CSV file in the final bucket
        final_object_key = f'folder/{os.path.basename(object_key)}'

        # Upload the CSV data to the FinalBucket
        s3.put_object(Bucket=final_bucket, Key=final_object_key, Body=csv_content)

        # Create QuickSight report using the CSV data
        result = create_quicksight_report(csv_content)

        s3.put_object(Bucket=final_bucket, Key=final_object_key, Body=result)

        if result == 'Success':
            return {
                'statusCode': 200,
                'body': json.dumps('Success')
            }
        else:
            return {
                'statusCode': 500,
                'body': json.dumps('Error')
            }
    except Exception as e:
        print(f'Error: {e}')
        return {
            'statusCode': 500,
            'body': json.dumps('Error')
        }