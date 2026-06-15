# -----------------------------------------------------------
# 1. IAM Role with Trust Policy
# -----------------------------------------------------------
resource "aws_iam_role" "doit_role" {
  name = local.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${var.doit_account_id}:root" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "sts:ExternalId" = var.external_id
        }
      }
    }]
  })

  tags = {
    ManagedBy = "terraform"
    Purpose   = "DoiT-CloudConnect"
    Features  = join("+", local.final_feature_list)
  }
}

# -----------------------------------------------------------
# 2. Inline PartnerAccess policy (always)
# -----------------------------------------------------------
resource "aws_iam_role_policy" "partner_access" {
  name = "PartnerAccess"
  role = aws_iam_role.doit_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["iam:List*", "iam:Get*"]
      Resource = "*"
    }]
  })
}

# -----------------------------------------------------------
# 3. Customer-managed policies
# -----------------------------------------------------------

# Core policy — always created
resource "aws_iam_policy" "core" {
  name        = "${local.role_name}-core"
  description = "DoiT core read-only permissions. Managed by terraform-doit-module."
  policy      = local.core_policy

  tags = {
    ManagedBy  = "terraform"
    PolicyType = "core"
  }
}

resource "aws_iam_role_policy_attachment" "core" {
  role       = aws_iam_role.doit_role.name
  policy_arn = aws_iam_policy.core.arn
}

# Write policy — only when write features are selected
resource "aws_iam_policy" "write" {
  count = local.has_write_features ? 1 : 0

  name        = "${local.role_name}-write"
  description = "DoiT write permissions. Managed by terraform-doit-module."
  policy      = local.write_policy

  tags = {
    ManagedBy  = "terraform"
    PolicyType = "write"
  }
}

resource "aws_iam_role_policy_attachment" "write" {
  count = local.has_write_features ? 1 : 0

  role       = aws_iam_role.doit_role.name
  policy_arn = aws_iam_policy.write[0].arn
}

# RealTimeData policy — only when real_time_data feature is selected
resource "aws_iam_policy" "real_time_data" {
  count = local.real_time_data_enabled ? 1 : 0

  name        = "${local.role_name}-real-time-data"
  description = "DoiT RealTimeData S3 and KMS permissions. Managed by terraform-doit-module."
  policy      = local.real_time_data_policy

  tags = {
    ManagedBy  = "terraform"
    PolicyType = "real_time_data"
  }

  lifecycle {
    precondition {
      condition     = local.real_time_data_bucket_name != ""
      error_message = "feature_config.real-time-data.bucket_name is required when real-time-data feature is enabled."
    }

    precondition {
      condition     = local.real_time_data_bucket_region != ""
      error_message = "feature_config.real-time-data.bucket_region is required when real-time-data feature is enabled."
    }
  }
}

resource "aws_iam_role_policy_attachment" "real_time_data" {
  count = local.real_time_data_enabled ? 1 : 0

  role       = aws_iam_role.doit_role.name
  policy_arn = aws_iam_policy.real_time_data[0].arn
}

# Composer policy — only when composer feature is selected
resource "aws_iam_policy" "composer" {
  count = contains(local.additional_feature_ids, "composer") ? 1 : 0

  name        = "${local.role_name}-composer"
  description = "DoiT Composer read-only permissions. Managed by terraform-doit-module."
  policy      = local.composer_policy

  tags = {
    ManagedBy  = "terraform"
    PolicyType = "composer"
  }
}

resource "aws_iam_role_policy_attachment" "composer" {
  count = contains(local.additional_feature_ids, "composer") ? 1 : 0

  role       = aws_iam_role.doit_role.name
  policy_arn = aws_iam_policy.composer[0].arn
}

# -----------------------------------------------------------
# 4. AWS managed policies — always attached
# -----------------------------------------------------------
resource "aws_iam_role_policy_attachment" "aws_managed" {
  for_each = local.aws_managed_policy_arns

  role       = aws_iam_role.doit_role.name
  policy_arn = each.value
}

# -----------------------------------------------------------
# 5. Notify DoiT backend — register role and activate features
# -----------------------------------------------------------
resource "time_sleep" "iam_propagation" {
  create_duration = "20s"

  depends_on = [
    aws_iam_role_policy.partner_access,
    aws_iam_role_policy_attachment.core,
    aws_iam_role_policy_attachment.write,
    aws_iam_role_policy_attachment.real_time_data,
    aws_iam_role_policy_attachment.composer,
    aws_iam_role_policy_attachment.aws_managed,
    aws_s3_bucket_notification.real_time_data,
    aws_iam_role.asg_opt,
    aws_iam_role_policy.asg_opt,
    aws_iam_role.support_gateway,
    aws_iam_role_policy.support_gateway_inline,
    aws_iam_role_policy_attachment.support_gateway,
    aws_iam_role.support_diagnostics,
    aws_iam_role_policy_attachment.support_diagnostics,
  ]
}

resource "doit_cloudconnect_aws_account" "this" {
  account_id       = var.account_id
  role_arn         = aws_iam_role.doit_role.arn
  enabled_features = local.cloudconnect_enabled_features
  s3bucket         = local.real_time_data_enabled ? local.real_time_data_bucket_name : null
  s3bucket_region  = local.real_time_data_enabled ? local.real_time_data_bucket_region : null

  depends_on = [time_sleep.iam_propagation]
}
