mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:root"
      user_id    = "123456789012"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_data "aws_s3_bucket" {
    defaults = {
      arn           = "arn:aws:s3:::existing-cur-bucket"
      bucket        = "existing-cur-bucket"
      bucket_region = "eu-west-1"
    }
  }

  mock_resource "aws_s3_bucket" {
    defaults = {
      arn           = "arn:aws:s3:::test-cur-export-bucket"
      bucket        = "test-cur-export-bucket"
      bucket_region = "us-east-1"
      id            = "test-cur-export-bucket"
    }
  }

  mock_resource "aws_bcmdataexports_export" {
    defaults = {
      arn = "arn:aws:bcm-data-exports:us-east-1:123456789012:export/doit-billing-export-mock"
    }
  }
}

variables {
  s3_bucket_name = "test-cur-export-bucket"
}

run "default_creates_bucket_hardening_policy_and_export" {
  command = apply

  # S3 bucket and hardening resources
  assert {
    condition     = length(aws_s3_bucket.this) == 1 && aws_s3_bucket.this[0].bucket == "test-cur-export-bucket" && aws_s3_bucket.this[0].force_destroy == false
    error_message = "Expected S3 bucket to be created with force_destroy = false by default."
  }

  assert {
    condition     = length(aws_s3_bucket_ownership_controls.this) == 1 && aws_s3_bucket_ownership_controls.this[0].rule[0].object_ownership == "BucketOwnerEnforced"
    error_message = "Expected BucketOwnerEnforced ownership controls."
  }

  assert {
    condition = (
      length(aws_s3_bucket_public_access_block.this) == 1 &&
      aws_s3_bucket_public_access_block.this[0].block_public_acls == true &&
      aws_s3_bucket_public_access_block.this[0].block_public_policy == true &&
      aws_s3_bucket_public_access_block.this[0].ignore_public_acls == true &&
      aws_s3_bucket_public_access_block.this[0].restrict_public_buckets == true
    )
    error_message = "Expected all four S3 Public Access Block flags to be true."
  }

  assert {
    condition     = length(aws_s3_bucket_server_side_encryption_configuration.this) == 1 && one(aws_s3_bucket_server_side_encryption_configuration.this[0].rule).apply_server_side_encryption_by_default[0].sse_algorithm == "AES256"
    error_message = "Expected SSE-S3 (AES256) default bucket encryption."
  }

  assert {
    condition     = length(aws_s3_bucket_versioning.this) == 1 && aws_s3_bucket_versioning.this[0].versioning_configuration[0].status == "Enabled"
    error_message = "Expected S3 bucket versioning to be enabled."
  }

  assert {
    condition = (
      length(aws_s3_bucket_lifecycle_configuration.this) == 1 &&
      aws_s3_bucket_lifecycle_configuration.this[0].rule[0].id == "expire-noncurrent-versions" &&
      aws_s3_bucket_lifecycle_configuration.this[0].rule[0].status == "Enabled" &&
      aws_s3_bucket_lifecycle_configuration.this[0].rule[0].noncurrent_version_expiration[0].noncurrent_days == 30 &&
      aws_s3_bucket_lifecycle_configuration.this[0].rule[0].abort_incomplete_multipart_upload[0].days_after_initiation == 7
    )
    error_message = "Expected S3 lifecycle configuration expiring noncurrent versions after 30 days and aborting incomplete multipart uploads after 7 days."
  }

  assert {
    condition     = length(data.aws_s3_bucket.existing) == 0
    error_message = "Expected existing bucket data source not to be read when create_s3_bucket = true."
  }

  # S3 bucket policy
  assert {
    condition     = length(aws_s3_bucket_policy.this) == 1
    error_message = "Expected S3 bucket policy to be managed when create_s3_bucket = true."
  }

  assert {
    condition = (
      length(jsondecode(aws_s3_bucket_policy.this[0].policy).Statement) == 2 &&
      jsondecode(aws_s3_bucket_policy.this[0].policy).Statement[0].Principal.Service == "bcm-data-exports.amazonaws.com" &&
      toset(jsondecode(aws_s3_bucket_policy.this[0].policy).Statement[0].Action) == toset(["s3:PutObject", "s3:GetBucketPolicy"]) &&
      toset(jsondecode(aws_s3_bucket_policy.this[0].policy).Statement[0].Resource) == toset([
        "arn:aws:s3:::test-cur-export-bucket",
        "arn:aws:s3:::test-cur-export-bucket/*",
      ]) &&
      jsondecode(aws_s3_bucket_policy.this[0].policy).Statement[0].Condition.StringEquals["aws:SourceAccount"] == "123456789012" &&
      jsondecode(aws_s3_bucket_policy.this[0].policy).Statement[0].Condition.ArnLike["aws:SourceArn"] == "arn:aws:bcm-data-exports:us-east-1:123456789012:export/*" &&
      jsondecode(aws_s3_bucket_policy.this[0].policy).Statement[1].Sid == "DenyInsecureTransport" &&
      jsondecode(aws_s3_bucket_policy.this[0].policy).Statement[1].Effect == "Deny" &&
      jsondecode(aws_s3_bucket_policy.this[0].policy).Statement[1].Principal == "*" &&
      jsondecode(aws_s3_bucket_policy.this[0].policy).Statement[1].Action == "s3:*" &&
      toset(jsondecode(aws_s3_bucket_policy.this[0].policy).Statement[1].Resource) == toset([
        "arn:aws:s3:::test-cur-export-bucket",
        "arn:aws:s3:::test-cur-export-bucket/*",
      ]) &&
      jsondecode(aws_s3_bucket_policy.this[0].policy).Statement[1].Condition.Bool["aws:SecureTransport"] == "false"
    )
    error_message = "S3 bucket policy must include both BCM Data Exports permissions and a TLS-only deny statement."
  }

  # BCM Data Export configuration
  assert {
    condition = (
      aws_bcmdataexports_export.this.export[0].name == "doit-billing-export" &&
      aws_bcmdataexports_export.this.export[0].refresh_cadence[0].frequency == "SYNCHRONOUS" &&
      aws_bcmdataexports_export.this.export[0].destination_configurations[0].s3_destination[0].s3_bucket == "test-cur-export-bucket" &&
      aws_bcmdataexports_export.this.export[0].destination_configurations[0].s3_destination[0].s3_prefix == "cur2" &&
      aws_bcmdataexports_export.this.export[0].destination_configurations[0].s3_destination[0].s3_region == "us-east-1" &&
      aws_bcmdataexports_export.this.export[0].destination_configurations[0].s3_destination[0].s3_output_configurations[0].format == "PARQUET" &&
      aws_bcmdataexports_export.this.export[0].destination_configurations[0].s3_destination[0].s3_output_configurations[0].compression == "PARQUET" &&
      aws_bcmdataexports_export.this.export[0].destination_configurations[0].s3_destination[0].s3_output_configurations[0].overwrite == "OVERWRITE_REPORT" &&
      aws_bcmdataexports_export.this.export[0].destination_configurations[0].s3_destination[0].s3_output_configurations[0].output_type == "CUSTOM"
    )
    error_message = "BCM Data Export destination or delivery settings do not match specification."
  }

  # All 8 COST_AND_USAGE_REPORT table configuration keys
  assert {
    condition = aws_bcmdataexports_export.this.export[0].data_query[0].table_configurations == tomap({
      COST_AND_USAGE_REPORT = tomap({
        BILLING_VIEW_ARN                      = "arn:aws:billing::123456789012:billingview/primary"
        TIME_GRANULARITY                      = "HOURLY"
        INCLUDE_RESOURCES                     = "TRUE"
        INCLUDE_CAPACITY_RESERVATION_DATA     = "TRUE"
        INCLUDE_IAM_PRINCIPAL_DATA            = "TRUE"
        INCLUDE_SPLIT_COST_ALLOCATION_DATA    = "FALSE"
        INCLUDE_MANUAL_DISCOUNT_COMPATIBILITY = "FALSE"
        INCLUDE_STANDARDIZED_COST_AND_RATE    = "FALSE"
      })
    })
    error_message = "Expected all 8 COST_AND_USAGE_REPORT table_configurations keys with DoiT-required values."
  }

  # Explicit 120-column SELECT list including all 16 DoiT required columns plus resource/capacity/IAM columns
  assert {
    condition = (
      length(local.cur_columns) == 120 &&
      startswith(aws_bcmdataexports_export.this.export[0].data_query[0].query_statement, "SELECT ") &&
      endswith(aws_bcmdataexports_export.this.export[0].data_query[0].query_statement, " FROM COST_AND_USAGE_REPORT") &&
      alltrue([
        for col in [
          "line_item_usage_account_id",
          "line_item_product_code",
          "line_item_usage_type",
          "line_item_usage_start_date",
          "line_item_usage_end_date",
          "line_item_availability_zone",
          "line_item_unblended_cost",
          "line_item_usage_amount",
          "bill_billing_period_start_date",
          "bill_billing_entity",
          "line_item_line_item_type",
          "line_item_operation",
          "pricing_unit",
          "line_item_line_item_description",
          "product",
          "tags",
          "line_item_resource_id",
          "capacity_reservation_capacity_reservation_arn",
          "capacity_reservation_capacity_reservation_status",
          "capacity_reservation_capacity_reservation_type",
          "line_item_iam_principal",
        ] : contains(local.cur_columns, col)
      ])
    )
    error_message = "CUR 2.0 query_statement must explicitly select all 120 columns including all DoiT required columns."
  }

  # Outputs
  assert {
    condition = (
      output.export_arn == "arn:aws:bcm-data-exports:us-east-1:123456789012:export/doit-billing-export-mock" &&
      output.export_name == "doit-billing-export" &&
      output.s3_bucket_name == "test-cur-export-bucket" &&
      output.s3_bucket_arn == "arn:aws:s3:::test-cur-export-bucket" &&
      output.s3_bucket_region == "us-east-1" &&
      output.s3_prefix == "cur2" &&
      output.cur_path == "cur2/doit-billing-export"
    )
    error_message = "Module outputs do not match expected values."
  }
}

run "existing_bucket_skips_s3_resources_and_policy_by_default" {
  command = apply

  variables {
    s3_bucket_name      = "existing-cur-bucket"
    create_s3_bucket    = false
    s3_bucket_policy_id = "existing-cur-bucket"
  }

  assert {
    condition = (
      length(aws_s3_bucket.this) == 0 &&
      length(aws_s3_bucket_ownership_controls.this) == 0 &&
      length(aws_s3_bucket_public_access_block.this) == 0 &&
      length(aws_s3_bucket_server_side_encryption_configuration.this) == 0 &&
      length(aws_s3_bucket_versioning.this) == 0 &&
      length(aws_s3_bucket_lifecycle_configuration.this) == 0 &&
      length(aws_s3_bucket_policy.this) == 0
    )
    error_message = "Expected zero S3 bucket, hardening, or bucket policy resources when create_s3_bucket = false."
  }

  assert {
    condition     = length(data.aws_s3_bucket.existing) == 1 && data.aws_s3_bucket.existing[0].bucket == "existing-cur-bucket"
    error_message = "Expected data.aws_s3_bucket.existing to look up the existing bucket."
  }

  assert {
    condition = (
      aws_bcmdataexports_export.this.export[0].destination_configurations[0].s3_destination[0].s3_bucket == "existing-cur-bucket" &&
      aws_bcmdataexports_export.this.export[0].destination_configurations[0].s3_destination[0].s3_region == "eu-west-1" &&
      output.s3_bucket_region == "eu-west-1" &&
      output.s3_bucket_arn == "arn:aws:s3:::existing-cur-bucket"
    )
    error_message = "Expected export and outputs to use existing bucket metadata from data.aws_s3_bucket.existing."
  }

  assert {
    condition = (
      length(jsondecode(output.s3_bucket_policy_statement_json).Statement) == 1 &&
      jsondecode(output.s3_bucket_policy_statement_json).Statement[0].Sid == "AllowDataExportsToWriteAndCheckPolicy" &&
      jsondecode(output.s3_bucket_policy_statement_json).Statement[0].Principal.Service == "bcm-data-exports.amazonaws.com" &&
      toset(jsondecode(output.s3_bucket_policy_statement_json).Statement[0].Resource) == toset([
        "arn:aws:s3:::existing-cur-bucket",
        "arn:aws:s3:::existing-cur-bucket/*",
      ])
    )
    error_message = "Expected s3_bucket_policy_statement_json output to contain only the BCM Data Exports statement for merging."
  }
}

run "existing_bucket_with_managed_policy" {
  command = apply

  variables {
    s3_bucket_name          = "existing-cur-bucket"
    create_s3_bucket        = false
    manage_s3_bucket_policy = true
  }

  assert {
    condition = (
      length(aws_s3_bucket.this) == 0 &&
      length(aws_s3_bucket_ownership_controls.this) == 0 &&
      length(aws_s3_bucket_public_access_block.this) == 0 &&
      length(aws_s3_bucket_server_side_encryption_configuration.this) == 0 &&
      length(aws_s3_bucket_versioning.this) == 0 &&
      length(aws_s3_bucket_lifecycle_configuration.this) == 0 &&
      length(aws_s3_bucket_policy.this) == 1 &&
      aws_s3_bucket_policy.this[0].bucket == "existing-cur-bucket" &&
      aws_s3_bucket_policy.this[0].region == "eu-west-1"
    )
    error_message = "Expected only aws_s3_bucket_policy and aws_bcmdataexports_export when create_s3_bucket = false and manage_s3_bucket_policy = true."
  }
}

run "existing_bucket_cross_account_with_region_override" {
  command = apply

  variables {
    s3_bucket_name   = "cross-account-cur-bucket"
    create_s3_bucket = false
    s3_bucket_region = "ap-southeast-1"
    s3_bucket_owner  = "210987654321"
    export_name      = "custom_export-1"
    s3_prefix        = "billing/cur2"
  }

  assert {
    condition     = length(data.aws_s3_bucket.existing) == 0
    error_message = "Expected data.aws_s3_bucket.existing to be skipped when s3_bucket_region is provided."
  }

  assert {
    condition = (
      aws_bcmdataexports_export.this.export[0].name == "custom_export-1" &&
      aws_bcmdataexports_export.this.export[0].destination_configurations[0].s3_destination[0].s3_bucket == "cross-account-cur-bucket" &&
      aws_bcmdataexports_export.this.export[0].destination_configurations[0].s3_destination[0].s3_region == "ap-southeast-1" &&
      aws_bcmdataexports_export.this.export[0].destination_configurations[0].s3_destination[0].s3_bucket_owner == "210987654321" &&
      aws_bcmdataexports_export.this.export[0].destination_configurations[0].s3_destination[0].s3_prefix == "billing/cur2" &&
      output.s3_bucket_arn == "arn:aws:s3:::cross-account-cur-bucket" &&
      output.cur_path == "billing/cur2/custom_export-1"
    )
    error_message = "Expected cross-account override inputs to propagate to export and outputs."
  }
}

run "new_bucket_with_custom_options_and_external_policy" {
  command = apply

  variables {
    s3_bucket_name                               = "test-cur-export-bucket"
    create_s3_bucket                             = true
    manage_s3_bucket_policy                      = false
    s3_bucket_force_destroy                      = true
    s3_bucket_noncurrent_version_expiration_days = 14
    s3_bucket_region                             = "eu-central-1"
    tags = {
      Environment = "test"
    }
  }

  assert {
    condition = (
      length(aws_s3_bucket.this) == 1 &&
      aws_s3_bucket.this[0].force_destroy == true &&
      aws_s3_bucket.this[0].region == "eu-central-1" &&
      aws_s3_bucket.this[0].tags == tomap({ Environment = "test" }) &&
      aws_s3_bucket_lifecycle_configuration.this[0].rule[0].noncurrent_version_expiration[0].noncurrent_days == 14 &&
      aws_bcmdataexports_export.this.tags == tomap({ Environment = "test" }) &&
      length(aws_s3_bucket_policy.this) == 0
    )
    error_message = "Expected force_destroy, lifecycle retention, region, tags, and manage_s3_bucket_policy = false to be applied."
  }
}
