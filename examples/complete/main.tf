provider "aws" {}

# Reads the API key from the DOIT_API_TOKEN environment variable.
provider "doit" {}

module "doit_cloudconnect" {
  source = "../.."

  external_id = var.external_id
  account_id  = var.account_id

  # Selecting every feature exceeds the default IAM quota of 10 managed
  # policies per role. Request an increase before applying.
  additional_features = [
    "Kubernetes auto connect clusters",
    "PerfectScale for Commitments - Read & Recommend",
    "PerfectScale for Commitments - Purchases",
    "PerfectScale for Spot",
    "Real-time anomalies",
    "DCI Composer",
    "Expert Advice",
    "Reflex",
    "Attribute",
  ]

  feature_config = {
    real-time-data = {
      bucket_name   = var.cur_bucket_name
      bucket_region = var.cur_bucket_region
    }
  }
}

output "role_arn" {
  description = "ARN of the IAM role DoiT assumes"
  value       = module.doit_cloudconnect.role_arn
}

output "enabled_features" {
  description = "Features enabled for the account"
  value       = module.doit_cloudconnect.enabled_features
}

output "support_gateway_role_arn" {
  description = "ARN of the DoiT Support Gateway role used by Expert Advice"
  value       = module.doit_cloudconnect.support_gateway_role_arn
}
