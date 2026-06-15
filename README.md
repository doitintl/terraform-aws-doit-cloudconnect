# terraform-aws-doit-cloudconnect

Terraform module for connecting AWS accounts with DoiT Cloud Intelligence (DCI) features. Creates IAM resources in the customer's AWS account to grant DoiT cross-account access based on selected features.

## What it does

- Creates an IAM role with a trust policy allowing DoiT to assume it via `sts:AssumeRole` with an external ID
- Attaches a **core** read-only managed policy (always present)
- Attaches a **write** managed policy when write features are selected
- Attaches feature-specific policies for **Composer**, **RealTimeData**, and **Expert Advice**
- Attaches three AWS managed policies: `SecurityAudit`, `AWSSavingsPlansReadOnlyAccess`, `Billing`
- Registers the account with DoiT CloudConnect after AWS resources are in place

## Supported features

| Customer feature name | Backend ID | Type | Description |
|-----------------------|------------|------|-------------|
| `Kubernetes auto connect clusters` | `fsk8s_auto_connect` | write | EKS access entries |
| `PerfectScale for Commitments - Read & Recommend` | `ps4commitment_core` | write | Commitment analysis |
| `PerfectScale for Commitments - Purchases` | `ps4commitment_purchase` | write | Savings Plans purchases |
| `PerfectScale for Spot` | `spot-scaling` | write | Also creates `doitintl-asg-opt` EventBridge role |
| `Real-time anomalies` | `real-time-data` | separate policy + bucket notification | S3 bucket access and object-created notifications to the DoiT prod SNS account `676206900418` (requires `bucket_name` and `bucket_region` config). Topic name is `realtime-event-topic-trigger` in `us-east-1` and `realtime-event-topic-trigger-<region>` elsewhere. |
| `DCI Composer` | `composer` | separate policy | Broad read-only access for Composer |
| `Expert Advice` | `expert-advice` | separate resources | DoiT Support Gateway (OIDC providers, support roles) |

Pass the customer feature names in `additional_features`. The module maps them to the backend IDs shown above when registering the account with DoiT CloudConnect.

## Usage

### Read-only (no additional features)

```hcl
module "doit_cloudconnect" {
  source = "github.com/doitintl/terraform-aws-doit-cloudconnect"

  external_id = var.doit_external_id # from DoiT Console
  account_id  = "123456789012"
}
```

### With write features

```hcl
module "doit_cloudconnect" {
  source = "github.com/doitintl/terraform-aws-doit-cloudconnect"

  external_id = var.doit_external_id
  account_id  = "123456789012"

  additional_features = ["PerfectScale for Spot", "Kubernetes auto connect clusters"]
}
```

### With resource-scoped features

```hcl
module "doit_cloudconnect" {
  source = "github.com/doitintl/terraform-aws-doit-cloudconnect"

  external_id = var.doit_external_id
  account_id  = "123456789012"

  additional_features = ["Real-time anomalies"]

  feature_config = {
    real-time-data = {
      bucket_name   = "my-cur-export-bucket"
      bucket_region = "us-east-1"
    }
  }
}
```

## Inputs

| Name | Description | Type | Default | Required | Sensitive |
|------|-------------|------|---------|----------|-----------|
| `external_id` | External ID from DoiT Console for trust policy | `string` | — | yes | yes |
| `account_id` | Customer AWS Account ID (12 digits) | `string` | — | yes | no |
| `doit_account_id` | DoiT AWS account ID for trust policy | `string` | `"068664126052"` | no | no |
| `additional_features` | Customer feature names to enable. The module maps them to DoiT backend feature IDs. | `list(string)` | `[]` | no | no |
| `feature_config` | Per-feature configuration map. Real-time anomalies uses the `real-time-data` key with `bucket_name` and `bucket_region`. | `map(map(string))` | `{}` | no | no |

## Outputs

| Name | Description |
|------|-------------|
| `role_arn` | ARN of the created IAM role |
| `role_name` | Name of the created IAM role |
| `enabled_features` | List of enabled features |
| `custom_policy_arns` | Map of policy type to customer-managed policy ARN |
| `aws_managed_policy_arns` | List of AWS managed policy ARNs attached to the role |
| `support_gateway_role_arn` | ARN of the DoiT Support Gateway role (null if Expert Advice not enabled) |
| `cloudconnect_time_linked` | Timestamp returned by DoiT when the account was linked |
| `cloudconnect_supported_features` | Supported DCI features and permission status returned by DoiT |

## Requirements

| Name | Version |
|------|---------|
| Terraform | >= 1.3 |
| AWS provider | ~> 6.50 |
| DoiT provider | >= 1.5.0 |
| Time provider | ~> 0.13 |

The root Terraform configuration using this module must configure the DoiT provider, preferably with `DOIT_API_TOKEN`:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.50"
    }
    doit = {
      source  = "doitintl/doit"
      version = ">= 1.5.0"
    }
  }
}

provider "doit" {}
```

## License

MIT
