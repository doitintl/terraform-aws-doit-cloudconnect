# CUR 2.0 Export

Creates a hardened S3 bucket, bucket policy, and AWS Cost and Usage Report (CUR) 2.0 Data Export configured for DoiT Cloud Intelligence AWS billing onboarding.

Run this example in your AWS Organizations management (payer) account. Only AWS credentials are required — no `doit` provider or API token is needed.

```shell
terraform init
terraform apply -var s3_bucket_name=my-org-doit-cur2-123456789012
```
