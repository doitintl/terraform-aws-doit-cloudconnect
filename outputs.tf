output "role_arn" {
  description = "ARN of the created IAM role"
  value       = aws_iam_role.doit_role.arn
}

output "role_name" {
  description = "Name of the created IAM role"
  value       = aws_iam_role.doit_role.name
}

output "enabled_features" {
  description = "List of features enabled for this account"
  value       = local.final_feature_list
}

output "custom_policy_arns" {
  description = "Map of policy type to customer-managed policy ARN"
  value = merge(
    { core = aws_iam_policy.core.arn },
    local.has_write_features ? { write = aws_iam_policy.write[0].arn } : {},
    length(aws_iam_policy.real_time_data) > 0 ? { real_time_data = aws_iam_policy.real_time_data[0].arn } : {},
    length(aws_iam_policy.composer) > 0 ? { composer = aws_iam_policy.composer[0].arn } : {},
  )
}

output "aws_managed_policy_arns" {
  description = "List of AWS managed policy ARNs attached to the role"
  value = concat(
    values(local.aws_managed_policy_arns),
    local.reflex_enabled ? values(local.reflex_managed_policy_arns) : [],
  )
}

output "support_gateway_role_arn" {
  description = "ARN of the DoiT Support Gateway role (Expert Advice feature)"
  value       = local.expert_advice_enabled ? aws_iam_role.support_gateway[0].arn : null
}

output "cloudconnect_time_linked" {
  description = "ISO 8601 timestamp returned by DoiT when the CloudConnect account was linked"
  value       = doit_cloudconnect_aws_account.this.time_linked
}

output "cloudconnect_supported_features" {
  description = "Supported DCI features and permission status returned by DoiT"
  value       = doit_cloudconnect_aws_account.this.supported_features
}
