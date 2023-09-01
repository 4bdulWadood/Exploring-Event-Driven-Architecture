# Thumbnail Generation Lamdba

This is the repository for Youtube Video, on how to use Terraform to create AWS Lambda and configure AWS S3 trigger

## Terraform Commands
```bash
$ terraform init
$ terraform plan
$ terraform apply
$ terraform destroy
```

## AWS CLI Commands
```bash
$ aws iam list-policies --query 'Policies[?PolicyName == `thumbnail_s3_policy`]'

$ aws iam list-roles --query 'Roles[?RoleName == `thumbnail_lambda_role`]'

$ aws lambda list-functions --query 'Functions[?FunctionName == `thumbnail_generation_lambda`]'

$ aws s3 ls | grep cp-
$ aws s3 ls s3://cp-original-image-bucket
$ aws s3 ls s3://cp-thumbnail-image-bucket

$ aws logs describe-log-groups --query 'logGroups[?logGroupName == `/aws/lambda/thumbnail_generation_lambda`]'
$ aws logs tail /aws/lambda/thumbnail_generation_lambda

$ aws s3 cp high_resolution_image.jpeg s3://cp-original-image-bucket
$ aws logs tail /aws/lambda/thumbnail_generation_lambda
$ aws s3 ls s3://cp-original-image-bucket
$ aws s3 ls s3://cp-thumbnail-image-bucket


```