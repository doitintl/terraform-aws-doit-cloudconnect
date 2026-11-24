# terraform-aws-doit-cloudconnect

[![Terraform Registry](https://img.shields.io/badge/terraform-registry-623CE4?logo=terraform)](https://registry.terraform.io/modules/doitintl/doit-cloudconnect/aws/latest)
[![Tests](https://github.com/doitintl/terraform-aws-doit-cloudconnect/actions/workflows/tests.yml/badge.svg)](https://github.com/doitintl/terraform-aws-doit-cloudconnect/actions/workflows/tests.yml)

Terraform module for connecting AWS accounts with DoiT Cloud Intelligence (DCI) features. Creates IAM resources in the customer's AWS account to grant DoiT cross-account access based on selected features.

This module is published to the [Terraform Registry](https://registry.terraform.io/modules/doitintl/doit-cloudconnect/aws/latest) and used by DoiT customers. Pin a released version, and see [CHANGELOG.md](CHANGELOG.md) for what changed between versions.

## What it does

- Creates an IAM role with a trust policy allowing DoiT to assume it via `sts:AssumeRole` with an external ID
- Attaches a **core** read-only managed policy (always present)
- Attaches a **write** managed policy when write features are selected
- Attaches feature-specific policies for **Composer**, **RealTimeData**, **Attribute**, and **Expert Advice**
- Attaches three AWS managed policies: `SecurityAudit`, `AWSSavingsPlansReadOnlyAccess`, `AWSBillingReadOnlyAccess`
- Registers the account with DoiT CloudConnect after AWS resources are in place

## Supported features

| Customer feature name                             | Backend ID               | Type                                  | Description                                                                                                                                                                                                                                                           |
| ------------------------------------------------- | ------------------------ | ------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Kubernetes auto connect clusters`                | `fsk8s_auto_connect`     | write                                 | EKS access entries                                                                                                                                                                                                                                                    |
| `PerfectScale for Commitments - Read & Recommend` | `ps4commitment_core`     | write                                 | Commitment analysis                                                                                                                                                                                                                                                   |
| `PerfectScale for Commitments - Purchases`        | `ps4commitment_purchase` | write                                 | Savings Plans purchases                                                                                                                                                                                                                                               |
| `PerfectScale for Spot`                           | `spot-scaling`           | write                                 | Also creates `doitintl-asg-opt` EventBridge role                                                                                                                                                                                                                      |
| `Real-time anomalies`                             | `real-time-data`         | separate policy + bucket notification | S3 bucket access and object-created notifications to the DoiT prod SNS account `676206900418` (requires `bucket_name` and `bucket_region` config). Topic name is `realtime-event-topic-trigger` in `us-east-1` and `realtime-event-topic-trigger-<region>` elsewhere. |
| `DCI Composer`                                    | `composer`               | separate policy                       | Broad read-only access for Composer                                                                                                                                                                                                                                   |
| `Expert Advice`                                   | `expert-advice`          | separate resources                    | DoiT Support Gateway (OIDC providers, support roles)                                                                                                                                                                                                                  |
| `Reflex`                                          | `reflex`                 | separate policy                       | Metadata-only read access for DoiT Reflex. AWS-managed `job-function/ViewOnlyAccess` and `AWSSupportAccess` (`SecurityAudit` already attached by core), plus a small policy for the reads they do not cover. Support write actions are denied.                        |
| `Attribute`                                       | `attribute`              | separate policy                       | Read access for Attribute cost and resource utilization analysis, plus Cost Explorer actions. See [Attribute permissions](#attribute-permissions).                                                                                      |

Pass the customer feature names in `additional_features`. The module maps them to the backend IDs shown above when registering the account with DoiT CloudConnect.

### Spot Scaling permissions

`PerfectScale for Spot` grants `iam:PassRole`, `ec2:RunInstances` and `ec2:TerminateInstances` on all resources. This is intentional: the feature converts your existing Auto Scaling groups and launches instances with the instance profiles they already use. Those roles and ASGs are yours, so they can't be enumerated in advance or restricted by DoiT-managed tags.

The role can only be assumed by DoiT's AWS account with your external ID, and the feature is opt-in. Leave `PerfectScale for Spot` out of `additional_features` if you don't want to grant these permissions.

### Attribute permissions

`Attribute` mostly reads data. Besides read access for cost and resource utilization analysis, it grants Cost Explorer actions that change account state:

- `ce:UpdateCostAllocationTagsStatus` activates or deactivates cost allocation tags. Activated tags appear in your billing data from the time they are activated.
- `ce:StartSavingsPlansPurchaseRecommendationGeneration` starts generating Savings Plans purchase recommendations. It does not purchase anything.

Leave `Attribute` out of `additional_features` if you don't want to grant these permissions.

### Managed policy quota

IAM limits each role to 10 attached managed policies by default. Selecting every optional feature exceeds that limit. The module attaches:

- always: the core policy plus `SecurityAudit`, `AWSSavingsPlansReadOnlyAccess` and `AWSBillingReadOnlyAccess`
- one policy each for write features, `Real-time anomalies`, `DCI Composer` and `Attribute`
- three for `Reflex`: its own policy plus `ViewOnlyAccess` and `AWSSupportAccess`

The quota is only exceeded when write features, `Real-time anomalies`, `DCI
Composer`, `Attribute` and `Reflex` are all selected. In that case, request an
increase of the IAM **Managed policies per role** quota in Service Quotas
before running `terraform apply`.

## Prerequisites

- AWS credentials with permission to create IAM resources and configure S3 bucket notifications for Real-time anomalies
- External ID from the DoiT Console
- DoiT API key for the DoiT Terraform provider

Provide the DoiT API key through the `DOIT_API_TOKEN` environment variable:

```shell
export DOIT_API_TOKEN="..."
```

Do not pass the DoiT API key to this module. The module uses the configured `doit` provider to register the account with DoiT CloudConnect.

## Usage

### Read-only (no additional features)

```hcl
module "doit_cloudconnect" {
  source  = "doitintl/doit-cloudconnect/aws"
  version = "0.2.1"

  external_id = var.doit_external_id # from DoiT Console
  account_id  = "123456789012"
}
```

### With write features

```hcl
module "doit_cloudconnect" {
  source  = "doitintl/doit-cloudconnect/aws"
  version = "0.2.1"

  external_id = var.doit_external_id
  account_id  = "123456789012"

  additional_features = ["PerfectScale for Spot", "Kubernetes auto connect clusters"]
}
```

### With resource-scoped features

```hcl
module "doit_cloudconnect" {
  source  = "doitintl/doit-cloudconnect/aws"
  version = "0.2.1"

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

### Custom trust policy

Restrict the trust policy to specific IAM roles in the DoiT account instead of the whole account, and/or add further trust statements (for example a time-boxed one). Either input works on its own:

```hcl
module "doit_cloudconnect" {
  source  = "doitintl/doit-cloudconnect/aws"
  version = "0.2.1"

  external_id = var.doit_external_id
  account_id  = "123456789012"

  doit_principal_arns = ["arn:aws:iam::068664126052:role/example-role"]

  additional_trust_policy_statements = [{
    Effect    = "Allow"
    Principal = { AWS = "arn:aws:iam::111111111111:role/example-other-role" }
    Action    = "sts:AssumeRole"
    Condition = {
      StringEquals = { "sts:ExternalId" = var.doit_external_id }
      DateLessThan = { "aws:CurrentTime" = "2026-12-31T00:00:00Z" }
    }
  }]
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.3 |
| aws | ~> 6.50 |
| doit | >= 1.5.0 |
| time | ~> 0.13 |

## Providers

| Name | Version |
| ---- | ------- |
| aws | ~> 6.50 |
| doit | >= 1.5.0 |
| time | ~> 0.13 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_iam_openid_connect_provider.concedefy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_openid_connect_provider.support_cre](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_policy.attribute](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.composer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.core](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.real_time_data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.reflex](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.write](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.asg_opt](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.doit_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.support_diagnostics](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.support_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.asg_opt](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.partner_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.support_gateway_inline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.attribute](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.aws_managed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.composer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.core](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.real_time_data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.reflex](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.reflex_managed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.support_diagnostics](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.support_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.write](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_s3_bucket_notification.real_time_data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_notification) | resource |
| [doit_cloudconnect_aws_account.this](https://registry.terraform.io/providers/doitintl/doit/latest/docs/resources/cloudconnect_aws_account) | resource |
| [time_sleep.iam_propagation](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| account_id | Customer AWS Account ID | `string` | n/a | yes |
| external_id | External ID from the DoiT Console for the IAM role trust policy | `string` | n/a | yes |
| additional_features | List of optional DCI features to enable. Customer-facing feature names are mapped to backend feature IDs. 'core' is always included automatically. | `list(string)` | `[]` | no |
| additional_trust_policy_statements | Extra statements appended to the role trust policy, as IAM policy statement objects. | `any` | `[]` | no |
| doit_account_id | DoiT AWS account ID for the trust policy principal | `string` | `"068664126052"` | no |
| doit_principal_arns | Restricts the trust policy to these DoiT IAM principals (e.g. a specific role) instead of the entire doit_account_id root. Must be in doit_account_id. Null keeps the account root. | `list(string)` | `null` | no |
| expert_advice_concedefy_audience | Audience of the DoiT Concedefy OIDC provider for Expert Advice. Null uses the DoiT production audience. Override only when instructed by DoiT. | `string` | `null` | no |
| expert_advice_support_oidc_host | Host of the DoiT Support OIDC provider for Expert Advice. Null uses the DoiT production host. Override only when instructed by DoiT. | `string` | `null` | no |
| feature_config | Per-feature configuration. Required keys depend on the feature. | `map(map(string))` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| aws_managed_policy_arns | List of AWS managed policy ARNs attached to the role |
| cloudconnect_supported_features | Supported DCI features and permission status returned by DoiT |
| cloudconnect_time_linked | ISO 8601 timestamp returned by DoiT when the CloudConnect account was linked |
| custom_policy_arns | Map of policy type to customer-managed policy ARN |
| enabled_features | List of features enabled for this account |
| role_arn | ARN of the created IAM role |
| role_name | Name of the created IAM role |
| support_gateway_role_arn | ARN of the DoiT Support Gateway role (Expert Advice feature) |
<!-- END_TF_DOCS -->

## Provider configuration

The root Terraform configuration using this module must configure the DoiT provider. Prefer `DOIT_API_TOKEN` instead of hardcoding the API key:

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

Alternatively, configure the provider with a sensitive Terraform variable:

```hcl
variable "doit_api_token" {
  type      = string
  sensitive = true
}

provider "doit" {
  api_token = var.doit_api_token
}
```

## Examples

- [basic](examples/basic): read-only access, no optional features
- [complete](examples/complete): every optional feature

## Development

Changes to this module reach customers through the Terraform Registry. Treat inputs, outputs and resource addresses as public API: breaking changes need a `!` in the commit type, and renamed resources need a `moved` block.

### Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) 1.7 or later, for `terraform test`
- [TFLint](https://github.com/terraform-linters/tflint)
- [terraform-docs](https://terraform-docs.io/user-guide/installation/)
- [pre-commit](https://pre-commit.com/#install)
- [uv](https://docs.astral.sh/uv/), or `python3`, for the policy parity check

### Tests

Run every check that CI runs:

```shell
scripts/tests/run-all.sh
```

It checks formatting and validates the module and examples. Then it runs `terraform test`, TFLint and the README docs check, and finally compares the IAM policies with DoiT's CloudFormation member template. `terraform test` uses mock providers, so no AWS or DoiT credentials are needed.

The Requirements, Inputs and Outputs sections of this README, between the `BEGIN_TF_DOCS` and `END_TF_DOCS` markers, are generated. After changing variables or outputs, run `terraform-docs .` instead of editing that block by hand.

### pre-commit

The hooks in [.pre-commit-config.yaml](.pre-commit-config.yaml) run the fast checks on every commit: whitespace and YAML checks, `terraform fmt`, `terraform validate`, and the commit message format. Install them once per clone:

```shell
pre-commit install --install-hooks
```

This installs both the `pre-commit` and `commit-msg` hooks. The commit message hook runs [scripts/dev/check-commits.sh](scripts/dev/check-commits.sh), the same script CI uses on pull requests.

### Commit messages

Commits follow [Conventional Commits](https://www.conventionalcommits.org/): `type(optional-scope): description`, with types `feat`, `fix`, `chore`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci` and `revert`. CI checks them on pull requests, because the changelog and the next version number are derived from them.

## Releasing

Releases are cut by tagging `main`. The Terraform Registry publishes every `vX.Y.Z` tag. See [docs/release.md](docs/release.md).

## License

MIT
