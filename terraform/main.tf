module "streaming" {
  source = "./modules/streaming"

  project_name = var.project_name
  shard_count  = 1
}

# Fetch current AWS account ID automatically
data "aws_caller_identity" "current" {}

module "storage" {
  source = "./modules/storage"

  project_name = var.project_name
  account_id   = data.aws_caller_identity.current.account_id

  snowpipe_sqs_arn = "arn:aws:sqs:ap-southeast-2:899630542326:sf-snowpipe-AIDA5C5RIVX3FURDWFBDY-SjNxsw8BcCgMUI_DVaPF8Q"
}

module "compute" {
  source = "./modules/compute"

  project_name       = var.project_name
  kinesis_stream_arn = module.streaming.stream_arn

  # Pass DynamoDB details
  user_state_table_name = module.storage.user_state_table_name
  user_state_table_arn  = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${module.storage.user_state_table_name}"

  alerts_table_name = module.storage.fraud_alerts_table_name
  alerts_table_arn  = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${module.storage.fraud_alerts_table_name}"
}

module "delivery" {
  source = "./modules/delivery"

  project_name       = var.project_name
  kinesis_stream_arn = module.streaming.stream_arn # From Kinesis
  bucket_arn         = module.storage.bucket_arn   # To S3
}