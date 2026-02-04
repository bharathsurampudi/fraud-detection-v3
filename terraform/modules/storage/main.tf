# --- S3 Bucket for Cold Path ---
resource "aws_s3_bucket" "raw_bucket" {
  bucket        = "${var.project_name}-raw-data-${var.account_id}" # Unique name
  force_destroy = true                                             # Allows deleting bucket even if it has data (Good for dev)

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

# --- IAM Role for Snowflake ---
resource "aws_iam_role" "snowflake_role" {
  name = "${var.project_name}-snowflake-role"

  # Initial Trust Policy (We will update this manually after Snowflake gives us its ID)
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::899630542326:user/purd1000-s"
        },
        "Action" : "sts:AssumeRole",
        "Condition" : {
          "StringEquals" : {
            "sts:ExternalId" : "BQ29206_SFCRole=4_L5oM3VdvwP5R9nomm2Z6V19pXqE="
          }
        }
      }
    ]
    }
  )
}

# --- Policy: Allow Snowflake to Read S3 ---
resource "aws_iam_role_policy" "snowflake_access" {
  name = "${var.project_name}-snowflake-access"
  role = aws_iam_role.snowflake_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.raw_bucket.arn,
          "${aws_s3_bucket.raw_bucket.arn}/*"
        ]
      }
    ]
  })
}



# --- S3 Event Notification ---
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.raw_bucket.id

  queue {
    queue_arn     = var.snowpipe_sqs_arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "raw/"
    filter_suffix = ".gz"
  }
}