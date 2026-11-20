# Basic

Connects an AWS account to DoiT with read-only access and no optional features.

```shell
export DOIT_API_TOKEN="..."
terraform init
terraform apply -var external_id=<from DoiT Console> -var account_id=123456789012
```
