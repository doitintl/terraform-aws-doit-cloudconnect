variable "external_id" {
  description = "External ID from the DoiT Console for the IAM role trust policy"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.external_id) > 0
    error_message = "external_id must not be empty."
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

variable "doit_principal_arns" {
  description = "Restricts the trust policy to these DoiT IAM principals (e.g. a specific role) instead of the entire doit_account_id root. Must be in doit_account_id. Null keeps the account root."
  type        = list(string)
  default     = null

  validation {
    condition     = var.doit_principal_arns == null ? true : length(var.doit_principal_arns) > 0 && alltrue([for arn in var.doit_principal_arns : can(regex("^arn:aws:iam::\\d{12}:(root|role/.+)$", arn))])
    error_message = "doit_principal_arns must be null or a non-empty list of IAM role or account root ARNs."
  }
}

variable "additional_trust_policy_statements" {
  description = "Extra statements appended to the role trust policy, as IAM policy statement objects."
  type        = any
  default     = []
}

variable "additional_features" {
  description = "List of optional DCI features to enable. Customer-facing feature names are mapped to backend feature IDs. 'core' is always included automatically."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for f in var.additional_features : contains(toset([
        "fsk8s_auto_connect",
        "ps4commitment_core",
        "ps4commitment_purchase",
        "spot-scaling",
        "real-time-data",
        "composer",
        "expert_advice",
        "perfectscale for spot",
        "kubernetes auto connect clusters",
        "perfectscale for commitments - read & recommend",
        "perfectscale for commitments - purchases",
        "real-time anomalies",
        "dci composer",
        "expert advice",
        "reflex",
      ]), lower(trimspace(f)))
    ])
    error_message = "Invalid feature name. Valid features: PerfectScale for Spot, Kubernetes auto connect clusters, PerfectScale for Commitments - Read & Recommend, PerfectScale for Commitments - Purchases, Real-time anomalies, DCI Composer, Expert Advice, Reflex. Backend IDs are also accepted."
  }
}

variable "feature_config" {
  description = "Per-feature configuration. Required keys depend on the feature."
  type        = map(map(string))
  default     = {}
}
