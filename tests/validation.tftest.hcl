mock_provider "aws" {
  mock_resource "aws_iam_openid_connect_provider" {
    defaults = { arn = "arn:aws:iam::123456789012:oidc-provider/mock" }
  }
}
mock_provider "doit" {}
mock_provider "time" {}

variables {
  external_id         = "x"
  account_id          = "123456789012"
  additional_features = ["expert-advice"]
}
run "host_ok_0" {
  command = plan
  variables {
    expert_advice_support_oidc_host = "support.cre.doit-intl.com"
  }
}

run "host_ok_1" {
  command = plan
  variables {
    expert_advice_support_oidc_host = "support.example.doit-intl.com"
  }
}

run "host_ok_2" {
  command = plan
  variables {
    expert_advice_support_oidc_host = "a.doit-intl.com"
  }
}

run "host_bad_0" {
  command = plan
  variables {
    expert_advice_support_oidc_host = "https://support.cre.doit-intl.com"
  }
  expect_failures = [var.expert_advice_support_oidc_host]
}

run "host_bad_1" {
  command = plan
  variables {
    expert_advice_support_oidc_host = "evil.com"
  }
  expect_failures = [var.expert_advice_support_oidc_host]
}

run "host_bad_2" {
  command = plan
  variables {
    expert_advice_support_oidc_host = "support.doit-intl.com.evil.com"
  }
  expect_failures = [var.expert_advice_support_oidc_host]
}

run "host_bad_3" {
  command = plan
  variables {
    expert_advice_support_oidc_host = "evildoit-intl.com"
  }
  expect_failures = [var.expert_advice_support_oidc_host]
}

run "host_bad_4" {
  command = plan
  variables {
    expert_advice_support_oidc_host = "doit-intl.com"
  }
  expect_failures = [var.expert_advice_support_oidc_host]
}

run "host_bad_5" {
  command = plan
  variables {
    expert_advice_support_oidc_host = "x.doit-intl.com:443"
  }
  expect_failures = [var.expert_advice_support_oidc_host]
}

run "host_bad_6" {
  command = plan
  variables {
    expert_advice_support_oidc_host = "x.doit-intl.com/path"
  }
  expect_failures = [var.expert_advice_support_oidc_host]
}

run "host_bad_7" {
  command = plan
  variables {
    expert_advice_support_oidc_host = "X.doit-intl.com"
  }
  expect_failures = [var.expert_advice_support_oidc_host]
}

run "host_bad_8" {
  command = plan
  variables {
    expert_advice_support_oidc_host = "-x.doit-intl.com"
  }
  expect_failures = [var.expert_advice_support_oidc_host]
}

run "host_bad_9" {
  command = plan
  variables {
    expert_advice_support_oidc_host = ""
  }
  expect_failures = [var.expert_advice_support_oidc_host]
}

run "aud_ok_0" {
  command = plan
  variables {
    expert_advice_concedefy_audience = "doit-support"
  }
}

run "aud_ok_1" {
  command = plan
  variables {
    expert_advice_concedefy_audience = "example-audience"
  }
}

run "aud_bad_0" {
  command = plan
  variables {
    expert_advice_concedefy_audience = "Doit-support"
  }
  expect_failures = [var.expert_advice_concedefy_audience]
}

run "aud_bad_1" {
  command = plan
  variables {
    expert_advice_concedefy_audience = "doit/support"
  }
  expect_failures = [var.expert_advice_concedefy_audience]
}

run "aud_bad_2" {
  command = plan
  variables {
    expert_advice_concedefy_audience = "short"
  }
  expect_failures = [var.expert_advice_concedefy_audience]
}

run "aud_bad_3" {
  command = plan
  variables {
    expert_advice_concedefy_audience = "doit-support-"
  }
  expect_failures = [var.expert_advice_concedefy_audience]
}

run "aud_bad_4" {
  command = plan
  variables {
    expert_advice_concedefy_audience = "1doit-support"
  }
  expect_failures = [var.expert_advice_concedefy_audience]
}

run "aud_bad_5" {
  command = plan
  variables {
    expert_advice_concedefy_audience = ""
  }
  expect_failures = [var.expert_advice_concedefy_audience]
}
