output "iam_arn" {
  description = "IAM Policy ARN"
  value = aws_iam_policy.thumbnail_s3_policy.arn
}

output "function_name" {
  description = "Lambda function name"
  value = aws_lambda_function.thumbnail_lambda.function_name
}

output "cloud_watch_arn" {
  description = "Cloudwatch ARN"
  value = aws_cloudwatch_log_group.thumbnail_cloudwatch.arn
}