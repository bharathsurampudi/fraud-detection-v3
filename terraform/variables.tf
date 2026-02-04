variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-southeast-2" # Sydney
}

variable "project_name" {
  description = "Project naming convention"
  type        = string
  default     = "fraud-detection-v3"
}