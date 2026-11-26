data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_s3_bucket" "existing" {
  count = !var.create_s3_bucket && var.s3_bucket_region == null ? 1 : 0

  bucket = var.s3_bucket_name
}

locals {
  manage_s3_bucket_policy = var.manage_s3_bucket_policy != null ? var.manage_s3_bucket_policy : var.create_s3_bucket

  s3_bucket_name = var.create_s3_bucket ? aws_s3_bucket.this[0].bucket : var.s3_bucket_name

  s3_bucket_arn = (
    var.create_s3_bucket
    ? aws_s3_bucket.this[0].arn
    : (
      length(data.aws_s3_bucket.existing) > 0
      ? data.aws_s3_bucket.existing[0].arn
      : "arn:${data.aws_partition.current.partition}:s3:::${var.s3_bucket_name}"
    )
  )

  s3_bucket_region = (
    var.create_s3_bucket
    ? aws_s3_bucket.this[0].bucket_region
    : coalesce(var.s3_bucket_region, try(data.aws_s3_bucket.existing[0].bucket_region, null))
  )

  s3_bucket_policy_region = var.create_s3_bucket ? var.s3_bucket_region : local.s3_bucket_region

  s3_bucket_export_policy_statement = {
    Sid    = "AllowDataExportsToWriteAndCheckPolicy"
    Effect = "Allow"
    Principal = {
      Service = "bcm-data-exports.amazonaws.com"
    }
    Action = [
      "s3:PutObject",
      "s3:GetBucketPolicy",
    ]
    Resource = [
      local.s3_bucket_arn,
      "${local.s3_bucket_arn}/*",
    ]
    Condition = {
      StringEquals = {
        "aws:SourceAccount" = data.aws_caller_identity.current.account_id
      }
      ArnLike = {
        "aws:SourceArn" = "arn:${data.aws_partition.current.partition}:bcm-data-exports:us-east-1:${data.aws_caller_identity.current.account_id}:export/*"
      }
    }
  }

  s3_bucket_policy_statement_json = jsonencode({
    Version   = "2012-10-17"
    Statement = [local.s3_bucket_export_policy_statement]
  })

  s3_bucket_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      local.s3_bucket_export_policy_statement,
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          local.s3_bucket_arn,
          "${local.s3_bucket_arn}/*",
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
    ]
  })
}

resource "aws_s3_bucket" "this" {
  count = var.create_s3_bucket ? 1 : 0

  bucket        = var.s3_bucket_name
  region        = var.s3_bucket_region
  force_destroy = var.s3_bucket_force_destroy
  tags          = var.tags
}

# S3 serializes per-bucket configuration mutations; chain bucket settings to
# prevent intermittent OperationAborted errors on first apply.
resource "aws_s3_bucket_ownership_controls" "this" {
  count = var.create_s3_bucket ? 1 : 0

  bucket = aws_s3_bucket.this[0].id
  region = var.s3_bucket_region

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  count = var.create_s3_bucket ? 1 : 0

  bucket = aws_s3_bucket.this[0].id
  region = var.s3_bucket_region

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  depends_on = [aws_s3_bucket_ownership_controls.this]
}

# SSE-S3 (AES256) rather than SSE-KMS: DoiT's billing role reads CUR objects
# without requiring kms:Decrypt permissions on a customer-managed key.
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  count = var.create_s3_bucket ? 1 : 0

  bucket = aws_s3_bucket.this[0].id
  region = var.s3_bucket_region

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }

  depends_on = [aws_s3_bucket_public_access_block.this]
}

resource "aws_s3_bucket_versioning" "this" {
  count = var.create_s3_bucket ? 1 : 0

  bucket = aws_s3_bucket.this[0].id
  region = var.s3_bucket_region

  versioning_configuration {
    status = "Enabled"
  }

  depends_on = [aws_s3_bucket_server_side_encryption_configuration.this]
}

resource "aws_s3_bucket_policy" "this" {
  count = local.manage_s3_bucket_policy ? 1 : 0

  bucket = local.s3_bucket_name
  region = local.s3_bucket_policy_region
  policy = local.s3_bucket_policy_json

  depends_on = [
    aws_s3_bucket_ownership_controls.this,
    aws_s3_bucket_public_access_block.this,
    aws_s3_bucket_server_side_encryption_configuration.this,
    aws_s3_bucket_versioning.this,
  ]
}

resource "aws_bcmdataexports_export" "this" {
  export {
    name        = var.export_name
    description = var.description

    data_query {
      query_statement = local.cur_query_statement

      # All COST_AND_USAGE_REPORT table configuration keys must be specified
      # explicitly to prevent inconsistent results after apply and drift.
      table_configurations = {
        COST_AND_USAGE_REPORT = {
          BILLING_VIEW_ARN                      = "arn:${data.aws_partition.current.partition}:billing::${data.aws_caller_identity.current.account_id}:billingview/primary"
          TIME_GRANULARITY                      = "HOURLY"
          INCLUDE_RESOURCES                     = "TRUE"
          INCLUDE_CAPACITY_RESERVATION_DATA     = "TRUE"
          INCLUDE_IAM_PRINCIPAL_DATA            = "TRUE"
          INCLUDE_SPLIT_COST_ALLOCATION_DATA    = "FALSE"
          INCLUDE_MANUAL_DISCOUNT_COMPATIBILITY = "FALSE"
          INCLUDE_STANDARDIZED_COST_AND_RATE    = "FALSE"
        }
      }
    }

    destination_configurations {
      s3_destination {
        s3_bucket       = local.s3_bucket_name
        s3_prefix       = var.s3_prefix
        s3_region       = local.s3_bucket_region
        s3_bucket_owner = var.s3_bucket_owner

        s3_output_configurations {
          format      = "PARQUET"
          compression = "PARQUET"
          overwrite   = "OVERWRITE_REPORT"
          output_type = "CUSTOM"
        }
      }
    }

    refresh_cadence {
      frequency = "SYNCHRONOUS"
    }
  }

  tags = var.tags

  # Reference var.s3_bucket_policy_id on the export resource only so callers
  # managing their own bucket policy can consume s3_bucket_policy_statement_json
  # and still order export creation after the policy without a module cycle.
  lifecycle {
    precondition {
      condition     = var.s3_bucket_policy_id == null || length(trimspace(var.s3_bucket_policy_id)) > 0
      error_message = "s3_bucket_policy_id must be null or a non-empty string."
    }
  }

  depends_on = [
    aws_s3_bucket_policy.this,
    aws_s3_bucket_versioning.this,
  ]
}
