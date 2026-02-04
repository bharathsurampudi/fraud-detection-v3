# --- S3 Bucket for Cold Path ---
resource "aws_s3_bucket" "raw_bucket" {
  bucket        = "${var.project_name}-raw-data-${var.account_id}" # Unique name
  force_destroy = true # Allows deleting bucket even if it has data (Good for dev)

  tags = {
    Name = "${var.project_name}-raw-storage"
  }
}

resource "aws_s3_bucket_public_access_block" "raw_bucket_block" {
  bucket = aws_s3_bucket.raw_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- DynamoDB: User State (Hot Path) ---
resource "aws_dynamodb_table" "user_state" {
  name         = "${var.project_name}-user-state"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"

  attribute {
    name = "user_id"
    type = "S" # String
  }

  ttl {
    attribute_name = "ttl" # Auto-delete old state to save costs
    enabled        = true
  }

  tags = {
    Name = "${var.project_name}-user-state"
  }
}

# --- DynamoDB: Fraud Alerts (Output) ---
resource "aws_dynamodb_table" "fraud_alerts" {
  name         = "${var.project_name}-alerts"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "transaction_id"

  attribute {
    name = "transaction_id"
    type = "S"
  }

  tags = {
    Name = "${var.project_name}-alerts"
  }
}