provider "aws" {}

# Reads the API key from the DOIT_API_TOKEN environment variable.
provider "doit" {}

module "doit_cloudconnect" {
  source = "../.."

  external_id = var.external_id
  account_id  = var.account_id
}

output "role_arn" {
  description = "ARN of the IAM role DoiT assumes"
  value       = module.doit_cloudconnect.role_arn
}
