terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "4.36.1"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }
  required_version = "~> 1.0"
}

data "aws_caller_identity" "current" {}

provider "aws" {
    region = var.aws_region
}

# Create an SNS Topic
resource "aws_sns_topic" "quicksight_report_topic" {
  name = "quicksight_report_topic"
}

# Subscribe an email address to the SNS topic
resource "aws_sns_topic_subscription" "quicksight_report_subscription" {
  topic_arn = aws_sns_topic.quicksight_report_topic.arn
  protocol  = "email"
  endpoint  = "a1syed@torontomu.ca"
}

resource "aws_iam_policy" "thumbnail_s3_policy" {
    name = "thumbnail_s3_policy"
    policy = jsonencode({
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Action": "s3:*",
            "Resource": "arn:aws:s3:::initialbucket564333/*"
        }, {
            "Effect": "Allow",
            "Action": "s3:*",
            "Resource": "arn:aws:s3:::destinationbucket564333/*"
        }]
    })
}

resource "aws_iam_policy_attachment" "dashboard_lambda_s3_policy_attachment" {
  name       = "dashboard_lambda_s3_policy_attachment"
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess" # Use an appropriate policy
  roles      = [aws_iam_role.thumbnail_lambda_role.name]
}

resource "aws_iam_role" "thumbnail_lambda_role" {
  name = "thumbnail_lambda_role"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }]
  })

  // Additional inline IAM policy attached to the role
  inline_policy {
    name = "thumbnail_lambda_s3_put_policy"
    policy = jsonencode({
      "Version": "2012-10-17",
      "Statement": [{
        "Effect": "Allow",
        "Action": "s3:*",
        "Resource": [
          "arn:aws:s3:::destinationbucket564333/*"
        ]
      }]
    })
  }
}

resource "aws_iam_policy_attachment" "quicksight_attachment" {
  name       = "quicksight_attachment"
  policy_arn = aws_iam_policy.quicksight_policy.arn
  roles      = [aws_iam_role.thumbnail_lambda_role.name]
}

resource "aws_iam_policy_attachment" "thumbnail_role_s3_policy_attachment" {
    name = "thumbnail_role_s3_policy_attachment"
    roles = [ aws_iam_role.thumbnail_lambda_role.name ]
    policy_arn = aws_iam_policy.thumbnail_s3_policy.arn
}

resource "aws_iam_policy_attachment" "thumbnail_role_lambda_policy_attachment" {
    name = "thumbnail_role_lambda_policy_attachment"
    roles = [ aws_iam_role.thumbnail_lambda_role.name ]
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "thumbnail_lambda_source_archive" {
  type = "zip"

  source_dir  = "${path.module}/src"
  output_path = "${path.module}/my-deployment.zip"
}

resource "aws_lambda_function" "send_message" {
    function_name = "send_message"
    filename = "${path.module}/my-deployment.zip"

    runtime = "python3.9"
    handler = "message.lambda_handler"
    memory_size = 256

    source_code_hash = data.archive_file.thumbnail_lambda_source_archive.output_base64sha256

    role = aws_iam_role.lambda_role.arn

    layers = [
        "arn:aws:lambda:us-east-1:770693421928:layer:Klayers-p39-pillow:1"
    ]
}

resource "aws_iam_policy" "lambda_sns_publish_policy" {
  name        = "LambdaSNSPublishPolicy"
  description = "IAM policy to allow Lambda to publish to an SNS topic."

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "sns:Publish"
        ],
        Effect   = "Allow",
        Resource = aws_sns_topic.quicksight_report_topic.arn # Replace with your SNS topic ARN
      },
      {
        Action = [
          "quicksight:CreateAnalysis",
          "quicksight:CreateDashboard",
          "quicksight:DescribeAnalysis",
          "quicksight:DescribeDashboard",
          "quicksight:ListDashboardVersions",
          "quicksight:UpdateDashboardPermissions",
          "quicksight:QueryDashboard",
          "quicksight:CreateDataSource",
          "quicksight:ExportToCSV"  # Add other required actions here
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ],
  })
}

resource "aws_iam_role" "lambda_role" {
  name = "LambdaSNSRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
      },
    ],
  })
}

resource "aws_iam_policy_attachment" "lambda_role_attachment" {
  name       = "LambdaSNSTopicAttachment"
  policy_arn = aws_iam_policy.lambda_sns_publish_policy.arn
  roles      = [aws_iam_role.lambda_role.name]
}


resource "aws_lambda_function" "thumbnail_lambda" {
    function_name = "thumbnail_generation_lambda"
    filename = "${path.module}/my-deployment.zip"

    runtime = "python3.9"
    handler = "app.lambda_handler"
    memory_size = 256

    source_code_hash = data.archive_file.thumbnail_lambda_source_archive.output_base64sha256

    role = aws_iam_role.thumbnail_lambda_role.arn

    layers = [
        "arn:aws:lambda:us-east-1:770693421928:layer:Klayers-p39-pillow:1"
    ]
}

resource "aws_lambda_function" "dashboard_lambda" {
    function_name = "dashboard_lambda"
    filename = "${path.module}/my-deployment.zip"

    runtime = "python3.9"
    handler = "dummy.lambda_handler"
    memory_size = 256

    source_code_hash = data.archive_file.thumbnail_lambda_source_archive.output_base64sha256

    role = aws_iam_role.thumbnail_lambda_role.arn

    layers = [
        "arn:aws:lambda:us-east-1:770693421928:layer:Klayers-p39-pillow:1"
    ]
}

resource "aws_s3_bucket" "thumbnail_original_image_bucket" {
  bucket = "initialbucket564333"
  acl = "public-read"
}

resource "aws_s3_bucket" "thumbnail_image_bucket" {
  bucket = "destinationbucket564333"
  acl = "public-read-write"
}

resource "aws_s3_bucket" "final_bucket" {
  bucket = "finalbucket564333"
  acl    = "private" # Set ACL as needed, e.g., "private" or "public-read-write"
}

# Create an S3 Event Notification for the S3 Bucket
resource "aws_s3_bucket_notification" "final_bucket_notification" {
  bucket = aws_s3_bucket.final_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.send_message.arn
    events             = ["s3:ObjectCreated:*"]
  }

  depends_on = [
    aws_lambda_permission.report_allow_bucket
  ]
}

#Resource to add bucket policy to a bucket 
resource "aws_s3_bucket_policy" "final_bucket_policy" {
  bucket = aws_s3_bucket.final_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowDashboardLambdaWrite",
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:PutObject",
        Resource  = "${aws_s3_bucket.final_bucket.arn}/*",
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id # Your AWS Account ID
          }
        }
      }
    ]
  })
}

#DataSource to generate a policy document
data "aws_iam_policy_document" "public_read_access" {
  statement {
    principals {
	  type = "*"
	  identifiers = ["*"]
	}

    actions = [
      "s3:PutObject",
    ]

    resources = [
      aws_s3_bucket.thumbnail_image_bucket.arn,
      "${aws_s3_bucket.thumbnail_image_bucket.arn}/*",
    ]
  }
}


resource "aws_lambda_permission" "thumbnail_allow_bucket" {
  statement_id = "AllowExecutionFromS3Bucket"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.thumbnail_lambda.arn
  principal = "s3.amazonaws.com"
  source_arn = aws_s3_bucket.thumbnail_original_image_bucket.arn
}

resource "aws_lambda_permission" "dashboard_allow_bucket" {
  statement_id = "AllowExecutionFromS3Bucket"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dashboard_lambda.arn
  principal = "s3.amazonaws.com"
  source_arn = aws_s3_bucket.thumbnail_image_bucket.arn
}

resource "aws_lambda_permission" "report_allow_bucket" {
  statement_id = "AllowExecutionFromS3Bucket"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.send_message.arn
  principal = "s3.amazonaws.com"
  source_arn = aws_s3_bucket.final_bucket.arn
}

resource "aws_sns_topic_policy" "bucket_sns_policy" {
  arn  = aws_sns_topic.quicksight_report_topic.arn

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowS3EventNotification",
        Effect    = "Allow",
        Principal = {
          Service = "s3.amazonaws.com"
        },
        Action    = "SNS:Publish",
        Resource  = aws_sns_topic.quicksight_report_topic.arn,
        Condition = {
          ArnLike = {
            "aws:SourceArn" = aws_s3_bucket.final_bucket.arn
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_notification" "thumbnail_notification" {
    bucket = aws_s3_bucket.thumbnail_original_image_bucket.id

    lambda_function {
        lambda_function_arn = aws_lambda_function.thumbnail_lambda.arn
        events = [ "s3:ObjectCreated:*" ]
    }

    depends_on = [
      aws_lambda_permission.thumbnail_allow_bucket
    ]
}

resource "aws_s3_bucket_notification" "dashboard_notification" {
    bucket = aws_s3_bucket.thumbnail_image_bucket.id

    lambda_function {
        lambda_function_arn = aws_lambda_function.dashboard_lambda.arn
        events = [ "s3:ObjectCreated:*" ]
    }

    depends_on = [
      aws_lambda_permission.dashboard_allow_bucket
    ]
}

resource "aws_iam_policy" "quicksight_policy" {
  name        = "quicksight_policy"
  description = "Policy for QuickSight"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "quicksight:CreateAnalysis",
          "quicksight:CreateDashboard",
          "quicksight:DescribeAnalysis",
          "quicksight:DescribeDashboard",
          "quicksight:ListDashboardVersions",
          "quicksight:UpdateDashboardPermissions",
          "quicksight:QueryDashboard",
          "quicksight:CreateDataSource",
          "quicksight:ExportToCSV",  # Add other required actions here
        ],
        Effect   = "Allow",
        Resource = "*",
      },
    ],
  })
}


resource "aws_cloudwatch_log_group" "thumbnail_cloudwatch" {
  name = "/aws/lambda/${aws_lambda_function.thumbnail_lambda.function_name}"

  retention_in_days = 30
}