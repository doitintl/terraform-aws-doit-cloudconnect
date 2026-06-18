locals {
  role_name = "doitintl_dci_cloudconnect"
  feature_name_to_id = {
    "fsk8s_auto_connect"                              = "fsk8s_auto_connect"
    "ps4commitment_core"                              = "ps4commitment_core"
    "ps4commitment_purchase"                          = "ps4commitment_purchase"
    "spot-scaling"                                    = "spot-scaling"
    "real-time-data"                                  = "real-time-data"
    "composer"                                        = "composer"
    "expert_advice"                                   = "expert-advice"
    "perfectscale for spot"                           = "spot-scaling"
    "kubernetes auto connect clusters"                = "fsk8s_auto_connect"
    "perfectscale for commitments - read & recommend" = "ps4commitment_core"
    "perfectscale for commitments - purchases"        = "ps4commitment_purchase"
    "real-time anomalies"                             = "real-time-data"
    "dci composer"                                    = "composer"
    "expert advice"                                   = "expert-advice"
    "reflex"                                          = "reflex"
  }
  additional_feature_ids = distinct([
    for feature in var.additional_features :
    local.feature_name_to_id[lower(trimspace(feature))]
  ])
  final_feature_list            = distinct(concat(["core"], local.additional_feature_ids))
  cloudconnect_enabled_features = local.additional_feature_ids

  # ---------------------------------------------------------
  # Feature categorization
  # ---------------------------------------------------------
  write_feature_names = ["fsk8s_auto_connect", "ps4commitment_core", "ps4commitment_purchase", "spot-scaling"]
  has_write_features  = length(setintersection(toset(local.additional_feature_ids), toset(local.write_feature_names))) > 0

  # ---------------------------------------------------------
  # Core policy — all read-only permissions, always attached.
  # Source: dev member.yml CoreManagedPolicy
  # ---------------------------------------------------------
  core_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CoreReadOnly"
        Effect = "Allow"
        Action = [
          "amplify:GetApp",
          "amplify:GetWebhook",
          "amplify:ListApps",
          "amplify:ListBackendEnvironments",
          "amplify:ListBranches",
          "amplify:ListDomainAssociations",
          "amplify:ListWebhooks",
          "backup:GetBackupPlan",
          "backup:ListBackupPlans",
          "bedrock:GetAgent",
          "bedrock:GetGuardrail",
          "bedrock:GetKnowledgeBase",
          "ce:GetCommitmentPurchaseAnalysis",
          "ce:GetReservationUtilization",
          "ce:GetSavingsPlansPurchaseRecommendation",
          "ce:GetSavingsPlansUtilizationDetails",
          "ce:ListCommitmentPurchaseAnalyses",
          "cloudwatch:GetMetricWidgetImage",
          "cloudwatch:ListMetrics",
          "cost-optimization-hub:ListRecommendations",
          "docdb:DescribeDBClusters",
          "dynamodb:DescribeStream",
          "eks:ListAccessPolicies",
          "es:GetUpgradeHistory",
          "es:GetUpgradeStatus",
          "glacier:GetVaultNotifications",
          "glacier:ListTagsForVault",
          "glue:GetConnections",
          "glue:GetCrawler",
          "glue:GetDatabase",
          "glue:GetTriggers",
          "glue:GetWorkflow",
          "glue:ListWorkflows",
          "kinesisanalytics:DescribeApplication",
          "lambda:GetFunctionConcurrency",
          "lambda:GetFunctionUrlConfig",
          "lambda:GetLayerVersionByArn",
          "networkmanager:GetCoreNetwork",
          "networkmanager:GetNetworkRoutes",
          "networkmanager:ListAttachments",
          "networkmanager:ListCoreNetworks",
          "s3:GetAccountPublicAccessBlock",
          "s3:GetBucketOwnershipControls",
          "s3:GetPublicAccessBlock",
          "support:DescribeCommunications",
          "support:DescribeIssueTypes",
          "support:DescribeServices",
          "support:DescribeSeverityLevels",
          "support:DescribeSupportLevel",
          "support:RefreshTrustedAdvisorCheck",
          "trustedadvisor:GetRecommendation",
          "trustedadvisor:ListChecks",
          "trustedadvisor:ListRecommendationResources",
          "trustedadvisor:ListRecommendations",
          "waf-regional:GetLoggingConfiguration",
          "waf:GetLoggingConfiguration",
          "waf:GetRule",
          "waf:ListRules",
          "wafv2:GetRuleGroup",
        ]
        Resource = "*"
      }
    ]
  })

  # ---------------------------------------------------------
  # Per-feature write actions.
  # Source: dev member.yml WritePermissionPolicy
  # ---------------------------------------------------------
  feature_write_actions = {
    fsk8s_auto_connect = [
      "eks:CreateAccessEntry",
      "eks:AssociateAccessPolicy",
      "eks:DisassociateAccessPolicy",
    ]
    ps4commitment_purchase = [
      "savingsplans:CreateSavingsPlan",
      "savingsplans:ReturnSavingsPlan",
      "savingsplans:DeleteQueuedSavingsPlan",
      "savingsplans:TagResource",
    ]
    spot-scaling = [
      "autoscaling:AttachInstances",
      "autoscaling:BatchDeleteScheduledAction",
      "autoscaling:BatchPutScheduledUpdateGroupAction",
      "autoscaling:CreateOrUpdateTags",
      "autoscaling:Describe*",
      "autoscaling:UpdateAutoScalingGroup",
      "cloudformation:Describe*",
      "ec2:CancelSpotInstanceRequests",
      "ec2:CreateLaunchTemplate",
      "ec2:CreateLaunchTemplateVersion",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:ModifyLaunchTemplate",
      "ec2:RunInstances",
      "ec2:TerminateInstances",
      "events:PutEvents",
      "events:PutRule",
      "events:PutTargets",
      "iam:PassRole",
    ]
    ps4commitment_core = [
      "ce:StartCommitmentPurchaseAnalysis",
    ]
  }

  # Combined write actions from all selected features
  wildcard_write_actions = flatten([
    for feature in local.additional_feature_ids :
    lookup(local.feature_write_actions, feature, [])
  ])

  # ---------------------------------------------------------
  # Write policy — combined write permissions.
  # Only created when write features are selected.
  # ---------------------------------------------------------
  write_policy = local.has_write_features ? jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "WritePermissions"
        Effect   = "Allow"
        Action   = local.wildcard_write_actions
        Resource = "*"
      }
    ]
  }) : null

  # ---------------------------------------------------------
  # RealTimeData policy — resource-scoped S3 + KMS access.
  # Source: dev member.yml RealTimeDataPolicy
  # ---------------------------------------------------------
  real_time_data_enabled       = contains(local.additional_feature_ids, "real-time-data")
  real_time_data_config        = lookup(var.feature_config, "real-time-data", {})
  real_time_data_bucket_name   = lookup(local.real_time_data_config, "bucket_name", "")
  real_time_data_bucket_region = lookup(local.real_time_data_config, "bucket_region", "")

  real_time_data_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAccessToCloudTrailS3Bucket"
        Effect = "Allow"
        Action = [
          "s3:PutBucketNotification",
          "s3:ListBucket",
          "s3:GetBucketNotification",
        ]
        Resource = "arn:aws:s3:::${local.real_time_data_bucket_name}"
      },
      {
        Sid    = "AllowAccessToCloudTrailS3BucketGetObjects"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
        ]
        Resource = "arn:aws:s3:::${local.real_time_data_bucket_name}/*"
      },
      {
        Sid    = "AllowKMSDecryptForCloudTrailBucket"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "kms:EncryptionContext:aws:s3:arn" = "arn:aws:s3:::${local.real_time_data_bucket_name}/*"
            "kms:ViaService"                   = "s3.*.amazonaws.com"
          }
        }
      },
    ]
  })

  # ---------------------------------------------------------
  # Composer policy — broad read-only access for Composer.
  # Source: dev member.yml ComposerPolicy
  # ---------------------------------------------------------
  composer_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ComposerReadOnly"
        Effect = "Allow"
        Action = [
          "access-analyzer:List*",
          "amplify:Get*",
          "amplify:List*",
          "apigateway:Get*",
          "appconfig:Get*",
          "appconfig:List*",
          "appsync:Get*",
          "appsync:List*",
          "athena:Get*",
          "athena:List*",
          "autoscaling:Describe*",
          "backup:Describe*",
          "backup:Get*",
          "backup:List*",
          "bedrock:Get*",
          "bedrock:List*",
          "budgets:Describe*",
          "ce:Get*",
          "cloudformation:Describe*",
          "cloudformation:Get*",
          "cloudfront:Get*",
          "cloudfront:List*",
          "cloudtrail:Describe*",
          "cloudtrail:Get*",
          "cloudtrail:List*",
          "cloudwatch:Describe*",
          "cloudwatch:Get*",
          "cloudwatch:List*",
          "config:Describe*",
          "cur:Describe*",
          "dax:DescribeClusters",
          "directconnect:Describe*",
          "dynamodb:Describe*",
          "dynamodb:List*",
          "ec2:Describe*",
          "ecs:Describe*",
          "ecs:List*",
          "eks:Describe*",
          "eks:List*",
          "elasticache:Describe*",
          "elasticbeanstalk:Describe*",
          "elasticfilesystem:Describe*",
          "elasticloadbalancing:Describe*",
          "es:Describe*",
          "es:List*",
          "events:Describe*",
          "events:List*",
          "firehose:DescribeDeliveryStream",
          "firehose:ListDeliveryStreams",
          "fsx:Describe*",
          "glue:Get*",
          "glue:List*",
          "guardduty:Get*",
          "guardduty:List*",
          "iam:Get*",
          "iam:List*",
          "identitystore:List*",
          "inspector2:List*",
          "kms:Describe*",
          "kms:GetKeyRotationStatus",
          "kms:List*",
          "lambda:Get*",
          "lambda:List*",
          "logs:Describe*",
          "logs:FilterLogEvents",
          "logs:Get*",
          "logs:List*",
          "organizations:Describe*",
          "organizations:List*",
          "pricing:Get*",
          "rds:Describe*",
          "rds:DescribeDBClusters",
          "rds:DescribeDBInstances",
          "rds:List*",
          "redshift:Describe*",
          "route53:Get*",
          "route53:List*",
          "route53domains:Get*",
          "route53domains:List*",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation",
          "s3:GetBucketLogging",
          "s3:GetBucketNotification",
          "s3:GetBucketObjectLockConfiguration",
          "s3:GetBucketPolicy",
          "s3:GetBucketPublicAccessBlock",
          "s3:GetBucketTagging",
          "s3:GetBucketVersioning",
          "s3:GetBucketWebsite",
          "s3:GetEncryptionConfiguration",
          "s3:GetLifecycleConfiguration",
          "s3:ListAllMyBuckets",
          "sagemaker:Describe*",
          "sagemaker:List*",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets",
          "securityhub:Describe*",
          "securityhub:Get*",
          "shield:Describe*",
          "sso:List*",
          "states:Describe*",
          "states:List*",
          "storagegateway:Describe*",
          "storagegateway:List*",
          "transfer:DescribeServer",
          "transfer:ListServers",
          "vpc-lattice:Get*",
          "vpc-lattice:List*",
        ]
        Resource = "*"
      }
    ]
  })

  # ---------------------------------------------------------
  # AWS managed policy ARNs — always attached to the role.
  # ---------------------------------------------------------
  aws_managed_policy_arns = {
    SecurityAudit                 = "arn:aws:iam::aws:policy/SecurityAudit"
    AWSSavingsPlansReadOnlyAccess = "arn:aws:iam::aws:policy/AWSSavingsPlansReadOnlyAccess"
    Billing                       = "arn:aws:iam::aws:policy/job-function/Billing"
  }

  # ---------------------------------------------------------
  # Reflex feature — AWS managed read-only policies, attached
  # only when the "reflex" feature is enabled. SecurityAudit is
  # already always-on via aws_managed_policy_arns above.
  # ---------------------------------------------------------
  reflex_enabled = contains(local.additional_feature_ids, "reflex")
  reflex_managed_policy_arns = {
    ReadOnlyAccess   = "arn:aws:iam::aws:policy/ReadOnlyAccess"
    AWSSupportAccess = "arn:aws:iam::aws:policy/AWSSupportAccess"
  }

  # ---------------------------------------------------------
  # Expert Advice — inline policy for Support Gateway role.
  # Source: dev member.yml DoiTSupportGatewayRole inline policy
  # ---------------------------------------------------------
  expert_advice_inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Custom"
        Effect = "Allow"
        Action = [
          "access-analyzer:ValidatePolicy",
          "airflow:GetEnvironment",
          "airflow:List*",
          "amplify:Get*",
          "amplify:List*",
          "aoss:BatchGet*",
          "aoss:Get*",
          "aoss:List*",
          "aps:Describe*",
          "aps:Get*",
          "aps:List*",
          "backup:Describe*",
          "backup:Get*",
          "backup:List*",
          "batch:Describe*",
          "batch:Get*",
          "batch:List*",
          "bedrock:Get*",
          "bedrock:List*",
          "ce:Describe*",
          "ce:Get*",
          "ce:List*",
          "codeartifact:List*",
          "compute-optimizer:Describe*",
          "compute-optimizer:Get*",
          "ds:Describe*",
          "ds:Get*",
          "ds:List*",
          "eks:AccessKubernetesApi",
          "eks:Describe*",
          "eks:List*",
          "fms:Get*",
          "fms:List*",
          "identitystore-auth:BatchGetSession",
          "identitystore-auth:ListSessions",
          "lambda:GetCapacityProvider",
          "mediapackage:Describe*",
          "mediapackage:List*",
          "mobiletargeting:List*",
          "network-firewall:Describe*",
          "network-firewall:List*",
          "osis:Get*",
          "osis:List*",
          "redshift-serverless:List*",
          "resource-groups:Get*",
          "resource-groups:List*",
          "s3:DescribeJob",
          "s3:GetStorageLens*",
          "s3:ListBucketVersions",
          "s3:ListJobs",
          "s3:ListStorageLens*",
          "servicequotas:Get*",
          "servicequotas:List*",
          "servicequotas:RequestServiceQuotaIncrease",
          "signin:ListTrustedIdentityPropagationApplicationsForConsole",
          "sso-directory:Describe*",
          "sso-directory:DescribeDirectory",
          "sso-directory:Get*",
          "sso-directory:List*",
          "sso-directory:Search*",
          "sso:Search*",
          "ssm:Describe*",
          "ssm:Get*",
          "ssm:List*",
          "support:*",
          "workspaces:List*",
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowKMSKeyUseViaAWSIAMIdentityCenterService"
        Effect = "Allow"
        Action = ["kms:Decrypt"]
        Condition = {
          StringLike = {
            "kms:EncryptionContext:aws:sso:instance-arn" = "*"
            "kms:ViaService"                             = "sso.*.amazonaws.com"
          }
        }
        Resource = "*"
      },
      {
        Sid    = "AllowKMSKeyUseViaAWSIdentityStoreService"
        Effect = "Allow"
        Action = ["kms:Decrypt"]
        Condition = {
          StringLike = {
            "kms:EncryptionContext:aws:identitystore:identitystore-arn" = "*"
            "kms:ViaService"                                            = "identitystore.*.amazonaws.com"
          }
        }
        Resource = "*"
      },
      {
        Sid      = "AllowKMSKeyDiscovery"
        Effect   = "Allow"
        Action   = ["kms:ListAliases", "kms:DescribeKey"]
        Resource = "*"
      },
      {
        Sid    = "AllowIdentitySyncAccess"
        Effect = "Allow"
        Action = [
          "identity-sync:GetSyncProfile",
          "identity-sync:ListSyncFilters",
          "identity-sync:GetSyncTarget",
        ]
        Resource = "arn:*:identity-sync:*:*:*/*"
      },
      {
        Sid    = "DenyAccessToPotentiallySensitiveSSMDataButDoiTManaged"
        Effect = "Deny"
        Action = ["ssm:GetDocument", "ssm:GetParameter*"]
        NotResource = [
          "arn:aws:ssm:*::document/AWSPremiumSupport-TroubleshootEKSCluster",
          "arn:aws:ssm:*::document/AWSSupport-TroubleshootEKSWorkerNode",
          "arn:aws:ssm:*::parameter/aws/service/eks/optimized-ami/*",
          "arn:aws:ssm:*::parameter/aws/service/ami-windows-latest/*",
        ]
      },
      {
        Sid      = "DenyAccessToPotentiallySensitiveData"
        Effect   = "Deny"
        Action   = ["ssm:GetDocument", "ssm:GetParameter*"]
        Resource = "*"
      },
      {
        Sid    = "EKSSSMTroubleshooting"
        Effect = "Allow"
        Action = ["ssm:GetDocument", "ssm:GetParameter*", "ssm:StartAutomationExecution"]
        Resource = [
          "arn:aws:ssm:*::document/AWSPremiumSupport-TroubleshootEKSCluster",
          "arn:aws:ssm:*::document/AWSSupport-TroubleshootEKSWorkerNode",
          "arn:aws:ssm:*::automation-definition/AWSPremiumSupport-TroubleshootEKSCluster:*",
          "arn:aws:ssm:*::automation-definition/AWSSupport-TroubleshootEKSWorkerNode:*",
          "arn:aws:ssm:*::parameter/aws/service/eks/optimized-ami/*",
          "arn:aws:ssm:*::parameter/aws/service/ami-windows-latest/*",
        ]
      },
      {
        Sid      = "PartnerLedSupportDiagnosticsToolUser"
        Effect   = "Allow"
        Action   = ["ts:*"]
        Resource = "*"
      },
      {
        Sid      = "PartnerLedSupportDiagnosticsToolPassRoleRequirement"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = "arn:aws:iam::${var.account_id}:role/SupportDiagnostics"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ts.amazonaws.com"
          }
        }
      },
    ]
  })

  # Expert Advice — managed policies for Support Gateway role
  expert_advice_managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonOpenSearchIngestionReadOnlyAccess",
    "arn:aws:iam::aws:policy/AmazonRDSPerformanceInsightsReadOnly",
    "arn:aws:iam::aws:policy/AWSBillingReadOnlyAccess",
    "arn:aws:iam::aws:policy/AWSCloudShellFullAccess",
    "arn:aws:iam::aws:policy/AWSPartnerLedSupportReadOnlyAccess",
    "arn:aws:iam::aws:policy/AWSSupportAccess",
    "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess",
    "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess",
    "arn:aws:iam::aws:policy/SecurityAudit",
  ]
}
