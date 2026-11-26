variable "s3_bucket_name" {
  description = "Name of the S3 bucket for CUR 2.0 exports. Created when create_s3_bucket is true; must already exist when false."
  type        = string

  validation {
    condition = (
      can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.s3_bucket_name)) &&
      !can(regex("\\.\\.", var.s3_bucket_name)) &&
      !can(regex("^\\d+\\.\\d+\\.\\d+\\.\\d+$", var.s3_bucket_name))
    )
    error_message = "s3_bucket_name must be a valid S3 bucket name: 3-63 lowercase letters, digits, hyphens or periods, starting and ending with a letter or digit, with no consecutive periods and not formatted as an IP address."
  }
}

variable "export_name" {
  description = "Name of the AWS BCM Data Export."
  type        = string
  default     = "doit-billing-export"

  validation {
    condition     = can(regex("^[0-9A-Za-z_-]{1,128}$", var.export_name))
    error_message = "export_name must be 1-128 characters containing only letters, digits, hyphens, and underscores."
  }
}

variable "s3_prefix" {
  description = "S3 key prefix under which CUR 2.0 files are delivered. Defaults to \"cur2\" to avoid colliding with Legacy CUR reports in shared buckets."
  type        = string
  default     = "cur2"

  validation {
    condition     = length(var.s3_prefix) > 0 && length(var.s3_prefix) <= 1024 && !can(regex("^/|/$|\\s", var.s3_prefix))
    error_message = "s3_prefix must be 1-1024 non-whitespace characters with no leading or trailing slash."
  }
}

variable "create_s3_bucket" {
  description = "Whether to create and harden a new S3 bucket (BucketOwnerEnforced, public access block, SSE-S3 AES256, versioning). Set to false to deliver exports into an existing bucket."
  type        = bool
  default     = true
}

variable "manage_s3_bucket_policy" {
  description = "Whether to manage the S3 bucket policy granting bcm-data-exports.amazonaws.com write access and denying non-TLS requests. Defaults to the value of create_s3_bucket so existing bucket policies are never overwritten accidentally."
  type        = bool
  default     = null
}

variable "s3_bucket_policy_id" {
  description = "Optional ID of an externally managed aws_s3_bucket_policy resource (for example, aws_s3_bucket_policy.existing.id) when manage_s3_bucket_policy is false. Orders aws_bcmdataexports_export creation after the external bucket policy without creating a module-level dependency cycle."
  type        = string
  default     = null

  validation {
    condition     = var.s3_bucket_policy_id == null ? true : length(trimspace(var.s3_bucket_policy_id)) > 0
    error_message = "s3_bucket_policy_id must be null or a non-empty string."
  }
}

variable "s3_bucket_region" {
  description = "AWS region of the destination S3 bucket. When create_s3_bucket is true, overrides the AWS provider region for the S3 resources. When create_s3_bucket is false, skips the data.aws_s3_bucket lookup (useful for cross-account buckets)."
  type        = string
  default     = null

  validation {
    condition     = var.s3_bucket_region == null || can(regex("^[a-z]{2,4}(-[a-z]+)+-\\d+$", var.s3_bucket_region))
    error_message = "s3_bucket_region must be null or a valid AWS region identifier (e.g. us-east-1, eu-west-1)."
  }
}

variable "s3_bucket_owner" {
  description = "12-digit AWS account ID of the S3 bucket owner for cross-account delivery. Leave null when delivering to a bucket in the current account."
  type        = string
  default     = null

  validation {
    condition     = var.s3_bucket_owner == null || can(regex("^\\d{12}$", var.s3_bucket_owner))
    error_message = "s3_bucket_owner must be null or a 12-digit AWS account ID."
  }
}

variable "s3_bucket_force_destroy" {
  description = "Whether terraform destroy deletes all objects in the created S3 bucket. Only applies when create_s3_bucket is true."
  type        = bool
  default     = false
}

variable "description" {
  description = "Description for the AWS BCM Data Export."
  type        = string
  default     = "Cost and Usage Report 2.0 export for DoiT Cloud Intelligence"

  validation {
    condition     = var.description == null ? true : length(var.description) <= 1024
    error_message = "description must be 1024 characters or fewer."
  }
}

variable "tags" {
  description = "Tags to apply to the created S3 bucket (when create_s3_bucket is true) and BCM Data Export."
  type        = map(string)
  default     = {}
}
