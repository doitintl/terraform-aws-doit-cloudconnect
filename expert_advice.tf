# -----------------------------------------------------------
# Expert Advice — DoiT Support Gateway (conditional)
# Source: dev member.yml lines 487-741
# -----------------------------------------------------------

locals {
  expert_advice_enabled = contains(local.additional_feature_ids, "expert-advice")
}

# --- OIDC Provider: DoiT Support CRE ---
resource "aws_iam_openid_connect_provider" "support_cre" {
  count = local.expert_advice_enabled ? 1 : 0

  url             = "https://support.cre.doit-intl.com"
  client_id_list  = [var.account_id]
  thumbprint_list = ["15c2b40aa2f322798666a6b332aaa03a6773019b", "08745487e891c19e3078c1f2a07e452950ef36f6"]

  tags = {
    "doit:support" = "true"
    ManagedBy      = "terraform"
  }
}

# --- OIDC Provider: Google Firebase (Concedefy) ---
resource "aws_iam_openid_connect_provider" "concedefy" {
  count = local.expert_advice_enabled ? 1 : 0

  url             = "https://securetoken.google.com/doit-support"
  client_id_list  = ["doit-support"]
  thumbprint_list = ["08745487e891c19e3078c1f2a07e452950ef36f6"]

  tags = {
    "doit:support" = "true"
    ManagedBy      = "terraform"
  }
}

# --- DoiT Support Gateway Role ---
resource "aws_iam_role" "support_gateway" {
  count = local.expert_advice_enabled ? 1 : 0

  name                 = "DoiT-Support-Gateway"
  max_session_duration = 21600

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = [
          aws_iam_openid_connect_provider.support_cre[0].arn,
          aws_iam_openid_connect_provider.concedefy[0].arn,
        ]
      }
      Action = ["sts:AssumeRoleWithWebIdentity", "sts:TagSession"]
      Condition = {
        StringEqualsIfExists = {
          "securetoken.google.com/doit-support:aud" = "doit-support"
          "support.cre.doit-intl.com:aud"           = var.account_id
        }
        "ForAllValues:StringEquals" = {
          "sts:TransitiveTagKeys" = ["DoitEnvironment"]
        }
        "Null" = {
          "sts:TransitiveTagKeys" = "false"
        }
        StringEquals = {
          "aws:RequestTag/DoitEnvironment" = var.account_id
        }
      }
    }]
  })

  tags = {
    "doit:support" = "true"
    "doit:version" = "20260223023550"
    ManagedBy      = "terraform"
  }
}

# --- Support Gateway managed policy attachments ---
resource "aws_iam_role_policy_attachment" "support_gateway" {
  for_each = local.expert_advice_enabled ? toset(local.expert_advice_managed_policy_arns) : toset([])

  role       = aws_iam_role.support_gateway[0].name
  policy_arn = each.value
}

# --- Support Gateway inline policy ---
resource "aws_iam_role_policy" "support_gateway_inline" {
  count = local.expert_advice_enabled ? 1 : 0

  name   = "inline"
  role   = aws_iam_role.support_gateway[0].id
  policy = local.expert_advice_inline_policy
}

# --- Support Diagnostics Role (Partner-Led Support) ---
resource "aws_iam_role" "support_diagnostics" {
  count = local.expert_advice_enabled ? 1 : 0

  name = "SupportDiagnostics"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AWSDiagnosticToolsServiceOnly"
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ts.amazonaws.com" }
    }]
  })

  tags = {
    "doit:support" = "true"
    ManagedBy      = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "support_diagnostics" {
  count = local.expert_advice_enabled ? 1 : 0

  role       = aws_iam_role.support_diagnostics[0].name
  policy_arn = "arn:aws:iam::aws:policy/AWSPartnerLedSupportReadOnlyAccess"
}
