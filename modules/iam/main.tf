data "aws_caller_identity" "current" {}

locals {
  # jsonencode rather than aws_iam_policy_document keeps the policy visible to offline tests.
  assume_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = { StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id } }
    }]
  })
}

resource "aws_iam_role" "execution" {
  name                 = "${var.name_prefix}-ecs-execution"
  path                 = "/nnat/"
  assume_role_policy   = local.assume_policy
  permissions_boundary = var.permissions_boundary_arn
}

resource "aws_iam_role_policy" "execution" {
  name = "pull-log-and-read-secrets"
  role = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid      = "EcrAuthorization"
          Effect   = "Allow"
          Action   = ["ecr:GetAuthorizationToken"]
          Resource = ["*"] # AWS offers no resource-level control for this action
        },
        {
          Sid      = "PullImages"
          Effect   = "Allow"
          Action   = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:BatchCheckLayerAvailability"]
          Resource = var.repository_arns
        },
        {
          Sid      = "WriteLogs"
          Effect   = "Allow"
          Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
          Resource = [for arn in var.log_group_arns : "${arn}:*"]
        },
        {
          Sid      = "ReadSecrets"
          Effect   = "Allow"
          Action   = ["secretsmanager:GetSecretValue"]
          Resource = var.secret_arns
        },
      ],
      length(var.kms_key_arns) == 0 ? [] : [{
        Sid      = "DecryptSecrets"
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = var.kms_key_arns
      }],
    )
  })
}

# The application calls no AWS API, so task roles carry no permissions. They exist so a future permission
# is attached to one service only.
resource "aws_iam_role" "task" {
  for_each = var.services

  name                 = "${var.name_prefix}-task-${each.key}"
  path                 = "/nnat/"
  assume_role_policy   = local.assume_policy
  permissions_boundary = var.permissions_boundary_arn
}
