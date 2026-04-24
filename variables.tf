variable "external_id" {
  description = "External ID from the DoiT Console for the IAM role trust policy"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.external_id) > 0
    error_message = "external_id must not be empty."
  }
}

variable "api_key" {
  description = "API key from the DoiT Console for webhook authentication"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.api_key) > 0
    error_message = "api_key must not be empty."
  }
}

variable "account_id" {
  description = "Customer AWS Account ID"
  type        = string

  validation {
    condition     = can(regex("^\\d{12}$", var.account_id))
    error_message = "account_id must be a 12-digit AWS account ID."
  }
}

variable "doit_account_id" {
  description = "DoiT AWS account ID for the trust policy principal"
  type        = string
  default     = "068664126052"

  validation {
    condition     = can(regex("^\\d{12}$", var.doit_account_id))
    error_message = "doit_account_id must be a 12-digit AWS account ID."
  }
}

variable "additional_features" {
  description = "List of optional DCI features to enable. 'core' is always included automatically."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for f in var.additional_features : contains([
        "fsk8s",
        "ps4_commitment_core",
        "ps4_commitment_purchase",
        "spot_scaling",
        "real_time_data",
        "composer",
        "expert_advice",
      ], f)
    ])
    error_message = "Invalid feature name. Valid features: fsk8s, ps4_commitment_core, ps4_commitment_purchase, spot_scaling, real_time_data, composer, expert_advice."
  }
}

variable "feature_config" {
  description = "Per-feature configuration. Required keys depend on the feature."
  type        = map(map(string))
  default     = {}
}
