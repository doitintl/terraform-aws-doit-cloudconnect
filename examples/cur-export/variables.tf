variable "s3_bucket_name" {
  description = "Globally unique name for the S3 bucket that receives CUR 2.0 exports."
  type        = string
}

variable "export_name" {
  description = "Name of the AWS BCM Data Export."
  type        = string
  default     = "doit-billing-export"
}

variable "s3_prefix" {
  description = "S3 key prefix for the CUR 2.0 export files."
  type        = string
  default     = "cur2"
}
