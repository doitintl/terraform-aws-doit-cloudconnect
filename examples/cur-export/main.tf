provider "aws" {}

module "cur_export" {
  source = "../../modules/cur-export"

  s3_bucket_name = var.s3_bucket_name
  export_name    = var.export_name
  s3_prefix      = var.s3_prefix
}

output "export_arn" {
  description = "ARN of the created AWS BCM Data Export."
  value       = module.cur_export.export_arn
}

output "export_name" {
  description = "Name of the created AWS BCM Data Export."
  value       = module.cur_export.export_name
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket receiving CUR 2.0 exports."
  value       = module.cur_export.s3_bucket_name
}

output "s3_bucket_region" {
  description = "AWS region of the S3 bucket receiving CUR 2.0 exports."
  value       = module.cur_export.s3_bucket_region
}

output "cur_path" {
  description = "Full S3 path (<s3_prefix>/<export_name>) for DoiT AWS billing onboarding."
  value       = module.cur_export.cur_path
}
