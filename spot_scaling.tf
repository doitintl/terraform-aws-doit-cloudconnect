# -----------------------------------------------------------
# SpotScaling — additional IAM role for EventBridge ASG events
# Source: dev member.yml DoitintlAsgOptRole
# -----------------------------------------------------------
resource "aws_iam_role" "asg_opt" {
  count = contains(local.additional_feature_ids, "spot-scaling") ? 1 : 0

  name        = "doitintl-asg-opt"
  description = "DoiT role to send ASG events"
  path        = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    ManagedBy = "terraform"
    Purpose   = "DoiT-SpotScaling"
  }
}

resource "aws_iam_role_policy" "asg_opt" {
  count = contains(local.additional_feature_ids, "spot-scaling") ? 1 : 0

  name = "doitintl-asg-opt"
  role = aws_iam_role.asg_opt[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["events:PutEvents"]
      Resource = "*"
    }]
  })
}
