# terraform-aws-doit-cloudconnect

Terraform module for connecting AWS accounts with DoiT Cloud Intelligence (DCI) features. Creates IAM resources in the customer's AWS account to grant DoiT cross-account access based on selected features.

## What it does

- Creates an IAM role with a trust policy allowing DoiT to assume it via `sts:AssumeRole` with an external ID
- Attaches a **core** read-only managed policy (always present)
- Attaches a **write** managed policy when write features are selected
- Attaches feature-specific policies for **Composer**, **RealTimeData**, and **Expert Advice**
- Attaches three AWS managed policies: `SecurityAudit`, `AWSSavingsPlansReadOnlyAccess`, `Billing`
- Notifies the DoiT backend via webhook after all resources are in place

## Supported features

| Feature | Type | Description |
|---------|------|-------------|
| `fsk8s` | write | Kubernetes auto-connect clusters (EKS access entries) |
| `ps4_commitment_core` | write | PerfectScale for Commitments - read & recommend |
| `ps4_commitment_purchase` | write | PerfectScale for Commitments - purchases |
| `spot_scaling` | write | PerfectScale for Spot (also creates `doitintl-asg-opt` EventBridge role) |
| `real_time_data` | separate policy | S3 bucket access for real-time cost data (requires `bucket_name` config) |
| `composer` | separate policy | Broad read-only access for Composer |
| `expert_advice` | separate resources | DoiT Support Gateway (OIDC providers, support roles) |

## Usage

### Read-only (no additional features)

```hcl
module "doit_cloudconnect" {
  source = "github.com/doitintl/terraform-aws-doit-cloudconnect"

  external_id = var.doit_external_id  # from DoiT Console
  api_key     = var.doit_api_key      # from DoiT Console
  account_id  = "123456789012"
}
```

### With write features

```hcl
module "doit_cloudconnect" {
  source = "github.com/doitintl/terraform-aws-doit-cloudconnect"

  external_id = var.doit_external_id
  api_key     = var.doit_api_key
  account_id  = "123456789012"

  additional_features = ["spot_scaling", "fsk8s"]
}
```

### With resource-scoped features

```hcl
module "doit_cloudconnect" {
  source = "github.com/doitintl/terraform-aws-doit-cloudconnect"

  external_id = var.doit_external_id
  api_key     = var.doit_api_key
  account_id  = "123456789012"

  additional_features = ["real_time_data"]

  feature_config = {
    real_time_data = {
      bucket_name = "my-cur-export-bucket"
    }
  }
}
```

## Inputs

| Name | Description | Type | Default | Required | Sensitive |
|------|-------------|------|---------|----------|-----------|
| `external_id` | External ID from DoiT Console for trust policy | `string` | — | yes | yes |
| `api_key` | API key from DoiT Console for webhook auth | `string` | — | yes | yes |
| `account_id` | Customer AWS Account ID (12 digits) | `string` | — | yes | no |
| `doit_account_id` | DoiT AWS account ID for trust policy | `string` | `"068664126052"` | no | no |
| `additional_features` | Optional DCI features to enable | `list(string)` | `[]` | no | no |
| `feature_config` | Per-feature configuration map | `map(map(string))` | `{}` | no | no |

## Outputs

| Name | Description |
|------|-------------|
| `role_arn` | ARN of the created IAM role |
| `role_name` | Name of the created IAM role |
| `enabled_features` | List of enabled features |
| `custom_policy_arns` | Map of policy type to customer-managed policy ARN |
| `aws_managed_policy_arns` | List of AWS managed policy ARNs attached to the role |
| `support_gateway_role_arn` | ARN of the DoiT Support Gateway role (null if Expert Advice not enabled) |

## Requirements

| Name | Version |
|------|---------|
| Terraform | >= 1.3 |
| AWS provider | ~> 5.0 |
| HTTP provider | ~> 3.0 |

## License

MIT
