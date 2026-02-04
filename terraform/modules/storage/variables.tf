variable "project_name" {
  type = string
}

variable "account_id" {
  type        = string
  description = "AWS Account ID to ensure unique bucket names"
}