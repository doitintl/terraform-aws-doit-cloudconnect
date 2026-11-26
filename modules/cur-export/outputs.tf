output "export_arn" {
  description = "ARN of the created AWS BCM Data Export."
  value       = aws_bcmdataexports_export.this.arn
}

output "export_name" {
  description = "Name of the created AWS BCM Data Export."
  value       = aws_bcmdataexports_export.this.export[0].name
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket receiving CUR 2.0 exports."
  value       = local.s3_bucket_name
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket receiving CUR 2.0 exports."
  value       = local.s3_bucket_arn
}

output "s3_bucket_region" {
  description = "AWS region of the S3 bucket receiving CUR 2.0 exports."
  value       = local.s3_bucket_region
}

output "s3_prefix" {
  description = "S3 key prefix where CUR 2.0 exports are written."
  value       = var.s3_prefix
}

output "cur_path" {
  description = "Full S3 path (<s3_prefix>/<export_name>) for DoiT AWS billing onboarding."
  value       = "${var.s3_prefix}/${var.export_name}"
}

output "s3_bucket_policy_statement_json" {
  description = "IAM policy document JSON granting bcm-data-exports.amazonaws.com write and policy-check permissions on the bucket. Pass to aws_iam_policy_document.source_policy_documents when merging into an existing bucket policy."
  value       = local.s3_bucket_policy_statement_json
}
