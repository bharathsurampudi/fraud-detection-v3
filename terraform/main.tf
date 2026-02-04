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
}