# Complete

Connects an AWS account to DoiT with every optional feature, including Real-time anomalies on a Cost and Usage Report bucket.

Selecting every feature attaches more than 10 managed policies to the role. Request an increase of the IAM **Managed policies per role** quota in Service Quotas before applying. See [Managed policy quota](../../README.md#managed-policy-quota).

```shell
export DOIT_API_TOKEN="..."
terraform init
terraform apply \
  -var external_id=<from DoiT Console> \
  -var account_id=123456789012 \
  -var cur_bucket_name=my-cur-export-bucket \
  -var cur_bucket_region=us-east-1
```
