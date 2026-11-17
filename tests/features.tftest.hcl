mock_provider "aws" {
  mock_resource "aws_iam_openid_connect_provider" {
    defaults = { arn = "arn:aws:iam::123456789012:oidc-provider/mock" }
  }
  mock_resource "aws_iam_policy" {
    defaults = { arn = "arn:aws:iam::123456789012:policy/mock" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/mock" }
  }
}
mock_provider "doit" {}
mock_provider "time" {}

variables {
  external_id         = "x"
  account_id          = "123456789012"
  additional_features = ["Attribute", "expert-advice"]
}

run "prod_defaults" {
  command = apply
  assert {
    condition     = length(aws_iam_policy.attribute) == 1 && jsondecode(aws_iam_policy.attribute[0].policy).Statement[0].Resource == "*"
    error_message = "attribute policy missing"
  }
  assert {
    condition     = length(flatten([for st in jsondecode(aws_iam_policy.attribute[0].policy).Statement : st.Action])) == 51 && jsondecode(aws_iam_policy.attribute[0].policy).Statement[1].Action == ["ce:StartSavingsPlansPurchaseRecommendationGeneration", "ce:UpdateCostAllocationTagsStatus"]
    error_message = "attribute action count"
  }
  assert {
    condition     = contains(doit_cloudconnect_aws_account.this.enabled_features, "attribute") && contains(doit_cloudconnect_aws_account.this.enabled_features, "expert-advice")
    error_message = "enabled_features"
  }
  assert {
    condition     = aws_iam_openid_connect_provider.support_cre[0].url == "https://support.cre.doit-intl.com" && aws_iam_openid_connect_provider.concedefy[0].url == "https://securetoken.google.com/doit-support" && aws_iam_openid_connect_provider.concedefy[0].client_id_list == toset(["doit-support"])
    error_message = "prod OIDC defaults"
  }
  assert {
    condition     = jsondecode(aws_iam_role.support_gateway[0].assume_role_policy).Statement[0].Condition.StringEqualsIfExists == { "securetoken.google.com/doit-support:aud" = "doit-support", "support.cre.doit-intl.com:aud" = "123456789012" }
    error_message = "prod trust audiences"
  }
}

run "overrides" {
  command = apply
  variables {
    expert_advice_support_oidc_host  = "support.example.doit-intl.com"
    expert_advice_concedefy_audience = "example-aud"
  }
  assert {
    condition     = aws_iam_openid_connect_provider.support_cre[0].url == "https://support.example.doit-intl.com" && aws_iam_openid_connect_provider.concedefy[0].url == "https://securetoken.google.com/example-aud" && aws_iam_openid_connect_provider.concedefy[0].client_id_list == toset(["example-aud"])
    error_message = "override OIDC"
  }
  assert {
    condition     = jsondecode(aws_iam_role.support_gateway[0].assume_role_policy).Statement[0].Condition.StringEqualsIfExists == { "securetoken.google.com/example-aud:aud" = "example-aud", "support.example.doit-intl.com:aud" = "123456789012" }
    error_message = "override trust audiences"
  }
}

run "no_attribute" {
  command = apply
  variables {
    additional_features = []
  }
  assert {
    condition     = length(aws_iam_policy.attribute) == 0 && !contains(keys(output.custom_policy_arns), "attribute")
    error_message = "attribute should be absent"
  }
}

run "all_features_attachment_count" {
  command = apply
  variables {
    additional_features = ["fsk8s_auto_connect", "ps4commitment_core", "ps4commitment_purchase", "spot-scaling", "real-time-data", "composer", "expert-advice", "reflex", "attribute"]
    feature_config      = { real-time-data = { bucket_name = "example-bucket", bucket_region = "us-east-1" } }
  }
  assert {
    condition     = 1 + length(aws_iam_role_policy_attachment.write) + length(aws_iam_role_policy_attachment.real_time_data) + length(aws_iam_role_policy_attachment.composer) + length(aws_iam_role_policy_attachment.attribute) + length(aws_iam_role_policy_attachment.reflex) + length(aws_iam_role_policy_attachment.reflex_managed) + length(aws_iam_role_policy_attachment.aws_managed) == 11
    error_message = "expected 11 managed policy attachments on the DoiT role"
  }
}
