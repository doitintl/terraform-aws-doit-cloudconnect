# AWS CUR 2.0 Data Export (`modules/cur-export`)

Creates an AWS Cost and Usage Report (CUR) 2.0 Data Export (`aws_bcmdataexports_export`) configured to match DoiT Cloud Intelligence AWS billing onboarding requirements, along with an optional hardened S3 bucket and bucket policy.

This submodule depends only on the `hashicorp/aws` provider — no `doit` provider or `external_id` is required.

## What it creates

- **CUR 2.0 Data Export** (`aws_bcmdataexports_export`):
  - Table: `COST_AND_USAGE_REPORT` with an explicit 120-column `SELECT` statement
  - Granularity and content: `HOURLY`, resource IDs (`INCLUDE_RESOURCES = TRUE`), capacity reservation data (`INCLUDE_CAPACITY_RESERVATION_DATA = TRUE`), and IAM principal data (`INCLUDE_IAM_PRINCIPAL_DATA = TRUE`)
  - Format and delivery: `PARQUET` / `PARQUET` compression, `OVERWRITE_REPORT`, `SYNCHRONOUS` refresh cadence
- **S3 bucket** (optional, enabled by default via `create_s3_bucket = true`):
  - `BucketOwnerEnforced` object ownership, all four S3 Public Access Block settings enabled, bucket versioning enabled with a lifecycle rule expiring noncurrent versions (default 30 days) and aborting incomplete multipart uploads after 7 days, and SSE-S3 (`AES256`) default encryption (not SSE-KMS, so DoiT's billing role can read reports without `kms:Decrypt`)
- **S3 bucket policy** (optional, defaults to `create_s3_bucket`):
  - Grants `bcm-data-exports.amazonaws.com` `s3:PutObject` and `s3:GetBucketPolicy` scoped to the current account (`aws:SourceAccount` and `aws:SourceArn`), and denies non-TLS (`aws:SecureTransport = false`) requests
  - When `create_s3_bucket = false`, bucket policy management defaults to `false` so existing policies (such as a Legacy CUR `billingreports.amazonaws.com` policy) are never overwritten; use the `s3_bucket_policy_statement_json` output to merge the statement safely and pass the external policy ID via `s3_bucket_policy_id` to order export creation after the policy.

## Prerequisites

- **Management (payer) account**: Apply this module in your AWS Organizations management account (or standalone payer account) to export consolidated billing data for the entire organization. Applying it in a member account exports data only for that member account.
- **IAM permissions**: The Terraform caller needs `bcm-data-exports:CreateExport`, `bcm-data-exports:GetExport`, `bcm-data-exports:UpdateExport`, `bcm-data-exports:DeleteExport`, `bcm-data-exports:TagResource`, `bcm-data-exports:UntagResource`, `bcm-data-exports:ListTagsForResource`, and S3 permissions for the destination bucket.
- **Initial delivery delay**: AWS can take up to 24 hours after export creation to deliver the first CUR 2.0 files to S3.

## Usage

### Create a new S3 bucket and CUR 2.0 export

```hcl
module "cur_export" {
  source  = "doitintl/doit-cloudconnect/aws//modules/cur-export"
  version = "0.3.0"

  s3_bucket_name = "my-org-doit-cur2-123456789012"
}
```

### Use an existing S3 bucket (for example, one shared with Legacy CUR)

When `create_s3_bucket = false`, `manage_s3_bucket_policy` defaults to `false` so your existing bucket policy is left untouched. AWS validates that `bcm-data-exports.amazonaws.com` can write to the bucket during `CreateExport`. Pass the external `aws_s3_bucket_policy` ID via `s3_bucket_policy_id` so Terraform updates the bucket policy before creating the export in a single `terraform apply` without a dependency cycle:

```hcl
data "aws_iam_policy_document" "existing_cur_bucket" {
  # Your existing bucket policy statements (e.g., Legacy CUR billingreports.amazonaws.com)
}

data "aws_iam_policy_document" "merged_cur_bucket" {
  source_policy_documents = [
    data.aws_iam_policy_document.existing_cur_bucket.json,
    module.cur_export.s3_bucket_policy_statement_json,
  ]
}

resource "aws_s3_bucket_policy" "existing_cur_bucket" {
  bucket = "my-existing-cur-bucket"
  policy = data.aws_iam_policy_document.merged_cur_bucket.json
}

module "cur_export" {
  source  = "doitintl/doit-cloudconnect/aws//modules/cur-export"
  version = "0.3.0"

  s3_bucket_name      = "my-existing-cur-bucket"
  create_s3_bucket    = false
  s3_prefix           = "cur2"
  s3_bucket_policy_id = aws_s3_bucket_policy.existing_cur_bucket.id
}
```

If the existing bucket is dedicated to this export and has no conflicting bucket policy, set `manage_s3_bucket_policy = true` to let the module attach the policy directly.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.3 |
| aws | ~> 6.50 |

## Providers

| Name | Version |
| ---- | ------- |
| aws | ~> 6.50 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_bcmdataexports_export.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/bcmdataexports_export) | resource |
| [aws_s3_bucket.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_ownership_controls.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_s3_bucket.existing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/s3_bucket) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| s3_bucket_name | Name of the S3 bucket for CUR 2.0 exports. Created when create_s3_bucket is true; must already exist when false. | `string` | n/a | yes |
| create_s3_bucket | Whether to create and harden a new S3 bucket (BucketOwnerEnforced, public access block, SSE-S3 AES256, versioning with noncurrent-version expiration). Set to false to deliver exports into an existing bucket. | `bool` | `true` | no |
| description | Description for the AWS BCM Data Export. | `string` | `"Cost and Usage Report 2.0 export for DoiT Cloud Intelligence"` | no |
| export_name | Name of the AWS BCM Data Export. | `string` | `"doit-billing-export"` | no |
| manage_s3_bucket_policy | Whether to manage the S3 bucket policy granting bcm-data-exports.amazonaws.com write access and denying non-TLS requests. Defaults to the value of create_s3_bucket so existing bucket policies are never overwritten accidentally. | `bool` | `null` | no |
| s3_bucket_force_destroy | Whether terraform destroy deletes all objects in the created S3 bucket. Only applies when create_s3_bucket is true. | `bool` | `false` | no |
| s3_bucket_noncurrent_version_expiration_days | Number of days after which noncurrent S3 object versions created by CUR 2.0 report overwrites are expired. Only applies when create_s3_bucket is true. | `number` | `30` | no |
| s3_bucket_owner | 12-digit AWS account ID of the S3 bucket owner for cross-account delivery. Leave null when delivering to a bucket in the current account. | `string` | `null` | no |
| s3_bucket_policy_id | Optional ID of an externally managed aws_s3_bucket_policy resource (for example, aws_s3_bucket_policy.existing.id) when manage_s3_bucket_policy is false. Orders aws_bcmdataexports_export creation after the external bucket policy without creating a module-level dependency cycle. | `string` | `null` | no |
| s3_bucket_region | AWS region of the destination S3 bucket. When create_s3_bucket is true, overrides the AWS provider region for the S3 resources. When create_s3_bucket is false, skips the data.aws_s3_bucket lookup (useful for cross-account buckets). | `string` | `null` | no |
| s3_prefix | S3 key prefix under which CUR 2.0 files are delivered. Defaults to "cur2" to avoid colliding with Legacy CUR reports in shared buckets. | `string` | `"cur2"` | no |
| tags | Tags to apply to the created S3 bucket (when create_s3_bucket is true) and BCM Data Export. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| cur_path | Full S3 path (<s3_prefix>/<export_name>) for DoiT AWS billing onboarding. |
| export_arn | ARN of the created AWS BCM Data Export. |
| export_name | Name of the created AWS BCM Data Export. |
| s3_bucket_arn | ARN of the S3 bucket receiving CUR 2.0 exports. |
| s3_bucket_name | Name of the S3 bucket receiving CUR 2.0 exports. |
| s3_bucket_policy_statement_json | IAM policy document JSON granting bcm-data-exports.amazonaws.com write and policy-check permissions on the bucket. Pass to aws_iam_policy_document.source_policy_documents when merging into an existing bucket policy. |
| s3_bucket_region | AWS region of the S3 bucket receiving CUR 2.0 exports. |
| s3_prefix | S3 key prefix where CUR 2.0 exports are written. |
<!-- END_TF_DOCS -->
