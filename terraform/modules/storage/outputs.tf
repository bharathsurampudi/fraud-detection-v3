output "bucket_arn" {
  value = aws_s3_bucket.raw_bucket.arn
}

output "bucket_name" {
  value = aws_s3_bucket.raw_bucket.bucket
}

output "user_state_table_name" {
  value = aws_dynamodb_table.user_state.name
}

output "fraud_alerts_table_name" {
  value = aws_dynamodb_table.fraud_alerts.name
}