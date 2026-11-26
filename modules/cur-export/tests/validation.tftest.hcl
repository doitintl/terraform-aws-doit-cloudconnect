mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:root"
      user_id    = "123456789012"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_resource "aws_s3_bucket" {
    defaults = {
      arn           = "arn:aws:s3:::valid-cur-bucket"
      bucket        = "valid-cur-bucket"
      bucket_region = "us-east-1"
      id            = "valid-cur-bucket"
    }
  }
}

variables {
  s3_bucket_name = "valid-cur-bucket"
}

run "s3_bucket_name_valid_min_length" {
  command = plan
  variables {
    s3_bucket_name = "abc"
  }
}

run "s3_bucket_name_valid_with_dots" {
  command = plan
  variables {
    s3_bucket_name = "org.cur-export.123456789012"
  }
}

run "s3_bucket_name_too_short" {
  command = plan
  variables {
    s3_bucket_name = "ab"
  }
  expect_failures = [var.s3_bucket_name]
}

run "s3_bucket_name_uppercase" {
  command = plan
  variables {
    s3_bucket_name = "Invalid-Bucket"
  }
  expect_failures = [var.s3_bucket_name]
}

run "s3_bucket_name_consecutive_dots" {
  command = plan
  variables {
    s3_bucket_name = "bad..bucket"
  }
  expect_failures = [var.s3_bucket_name]
}

run "s3_bucket_name_ip_address" {
  command = plan
  variables {
    s3_bucket_name = "192.168.1.1"
  }
  expect_failures = [var.s3_bucket_name]
}

run "s3_bucket_name_leading_hyphen" {
  command = plan
  variables {
    s3_bucket_name = "-bad-bucket"
  }
  expect_failures = [var.s3_bucket_name]
}

run "export_name_valid" {
  command = plan
  variables {
    export_name = "DoiT_Billing-Export_2026"
  }
}

run "export_name_empty" {
  command = plan
  variables {
    export_name = ""
  }
  expect_failures = [var.export_name]
}

run "export_name_invalid_chars" {
  command = plan
  variables {
    export_name = "doit/billing.export"
  }
  expect_failures = [var.export_name]
}

run "s3_prefix_valid_nested" {
  command = plan
  variables {
    s3_prefix = "billing/cur2/prod"
  }
}

run "s3_prefix_empty" {
  command = plan
  variables {
    s3_prefix = ""
  }
  expect_failures = [var.s3_prefix]
}

run "s3_prefix_leading_slash" {
  command = plan
  variables {
    s3_prefix = "/cur2"
  }
  expect_failures = [var.s3_prefix]
}

run "s3_prefix_trailing_slash" {
  command = plan
  variables {
    s3_prefix = "cur2/"
  }
  expect_failures = [var.s3_prefix]
}

run "s3_prefix_whitespace" {
  command = plan
  variables {
    s3_prefix = "cur 2"
  }
  expect_failures = [var.s3_prefix]
}

run "s3_bucket_owner_valid" {
  command = plan
  variables {
    s3_bucket_owner = "123456789012"
  }
}

run "s3_bucket_owner_invalid_short" {
  command = plan
  variables {
    s3_bucket_owner = "12345"
  }
  expect_failures = [var.s3_bucket_owner]
}

run "s3_bucket_owner_invalid_non_digits" {
  command = plan
  variables {
    s3_bucket_owner = "12345678901a"
  }
  expect_failures = [var.s3_bucket_owner]
}

run "s3_bucket_region_valid" {
  command = plan
  variables {
    s3_bucket_region = "eu-central-1"
  }
}

run "s3_bucket_region_invalid" {
  command = plan
  variables {
    s3_bucket_region = "us_east_1"
  }
  expect_failures = [var.s3_bucket_region]
}

run "s3_bucket_policy_id_valid" {
  command = plan
  variables {
    s3_bucket_policy_id = "existing-cur-bucket"
  }
}

run "s3_bucket_policy_id_empty" {
  command = plan
  variables {
    s3_bucket_policy_id = ""
  }
  expect_failures = [var.s3_bucket_policy_id]
}

run "s3_bucket_policy_id_whitespace" {
  command = plan
  variables {
    s3_bucket_policy_id = "   "
  }
  expect_failures = [var.s3_bucket_policy_id]
}

run "s3_bucket_noncurrent_version_expiration_days_valid" {
  command = plan
  variables {
    s3_bucket_noncurrent_version_expiration_days = 7
  }
}

run "s3_bucket_noncurrent_version_expiration_days_zero" {
  command = plan
  variables {
    s3_bucket_noncurrent_version_expiration_days = 0
  }
  expect_failures = [var.s3_bucket_noncurrent_version_expiration_days]
}

run "s3_bucket_noncurrent_version_expiration_days_negative" {
  command = plan
  variables {
    s3_bucket_noncurrent_version_expiration_days = -5
  }
  expect_failures = [var.s3_bucket_noncurrent_version_expiration_days]
}

run "s3_bucket_noncurrent_version_expiration_days_non_integer" {
  command = plan
  variables {
    s3_bucket_noncurrent_version_expiration_days = 1.5
  }
  expect_failures = [var.s3_bucket_noncurrent_version_expiration_days]
}
