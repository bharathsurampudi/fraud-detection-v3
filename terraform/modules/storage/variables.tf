variable "project_name" {
  type = string
}

variable "account_id" {
  type        = string
  description = "AWS Account ID to ensure unique bucket names"
}

# --- Variable for the Snowflake SQS ARN ---
variable "snowpipe_sqs_arn" {
  type        = string
  description = "The SQS ARN from 'DESC PIPE' in Snowflake"
  default     = "" # We will pass this in from the root main.tf
}