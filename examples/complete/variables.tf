variable "external_id" {
  description = "External ID from the DoiT Console"
  type        = string
  sensitive   = true
}

variable "account_id" {
  description = "AWS account ID to connect to DoiT"
  type        = string
}

variable "cur_bucket_name" {
  description = "S3 bucket that receives the AWS Cost and Usage Report, for Real-time anomalies"
  type        = string
}

variable "cur_bucket_region" {
  description = "Region of the Cost and Usage Report bucket"
  type        = string
}
