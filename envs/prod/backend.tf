# The bucket and region are not committed: pass them at init time (see docs/guides/getting-started.md).
#   terraform init -backend-config="bucket=<state bucket>" -backend-config="region=<region>"
terraform {
  backend "s3" {
    key          = "prod/terraform.tfstate"
    use_lockfile = true # S3 native locking, no DynamoDB table
    encrypt      = true
  }
}
