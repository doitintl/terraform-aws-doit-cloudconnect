variable "external_id" {
  description = "External ID from the DoiT Console"
  type        = string
  sensitive   = true
}

variable "account_id" {
  description = "AWS account ID to connect to DoiT"
  type        = string
}
