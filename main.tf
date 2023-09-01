provider "aws" {
  region = "us-east-1"  # Change this to your desired region
}

resource "aws_s3_bucket" "source_bucket" {
  bucket = "source-bucket-462898"  # Change this to your desired source bucket name
  acl    = "private"

  versioning {
    enabled = true
  }
}

resource "aws_s3_bucket" "destination_bucket" {
  bucket = "destination-bucket-462898"  # Change this to your desired destination bucket name
  acl    = "private"

  versioning {
    enabled = true
  }
}

resource "aws_lambda_function" "json_to_csv_lambda" {
  filename      = "lambda_function.zip"  # Path to your Lambda deployment package
  function_name = "lambda_handler"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.8"
}

resource "aws_iam_role" "lambda_role" {
  name = "json-to-csv-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "lambda_policy_attachment" {
  name       = "lambda-policy-attachment"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_permission" "s3_lambda_permission" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.json_to_csv_lambda.arn
  principal     = "s3.amazonaws.com"
  
  source_arn = aws_s3_bucket.source_bucket.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.source_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.json_to_csv_lambda.arn
    events = ["s3:ObjectCreated:*"]
  }
}