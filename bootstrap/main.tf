data "aws_caller_identity" "current" {}

locals {
  account_id   = data.aws_caller_identity.current.account_id
  bucket_arn   = aws_s3_bucket.state.arn
  boundary_arn = aws_iam_policy.boundary.arn
  oidc_host    = "token.actions.githubusercontent.com"
  nnat_roles   = "arn:aws:iam::${local.account_id}:role/nnat/*"
}

# ---------------------------------------------------------------------------------------------------------
# Terraform state: one private, versioned, KMS-encrypted bucket. Each environment has its own key; locking
# uses an S3 lock object next to the state (use_lockfile), so there is no DynamoDB table.
# ---------------------------------------------------------------------------------------------------------

resource "aws_kms_key" "state" {
  description         = "${var.name_prefix} Terraform state encryption"
  enable_key_rotation = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AccountAdministration"
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${local.account_id}:root" }
      Action    = "kms:*"
      Resource  = "*" # in a key policy "*" means this key
    }]
  })
}

resource "aws_s3_bucket" "state" {
  #checkov:skip=CKV_AWS_18:Access logging needs a second bucket; state access is already recorded in CloudTrail
  #checkov:skip=CKV_AWS_144:Cross-region replication of state is out of scope for a single-account demo
  #checkov:skip=CKV2_AWS_62:No event consumers exist for state objects
  bucket = var.state_bucket_name

  # State must survive a careless destroy. Remove this line deliberately to retire the bucket.
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    bucket_key_enabled = true

    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.state.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [local.bucket_arn, "${local.bucket_arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.state]
}

# ---------------------------------------------------------------------------------------------------------
# GitHub OIDC: workflows get short-lived credentials; no AWS keys are stored in GitHub.
# ---------------------------------------------------------------------------------------------------------

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://${local.oidc_host}"
  client_id_list = ["sts.amazonaws.com"]
}

locals {
  state_access_read = [
    {
      Sid      = "ReadState"
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:ListBucket"]
      Resource = [local.bucket_arn, "${local.bucket_arn}/*"]
    },
    {
      Sid      = "LockState"
      Effect   = "Allow"
      Action   = ["s3:PutObject", "s3:DeleteObject"]
      Resource = ["${local.bucket_arn}/*.tflock"]
    },
    {
      Sid      = "DecryptState"
      Effect   = "Allow"
      Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
      Resource = [aws_kms_key.state.arn]
    },
  ]
}

# Pull requests: read-only on the account plus state read and lock. Secret values are denied explicitly.
resource "aws_iam_role" "plan" {
  name = "${var.name_prefix}-ci-plan"
  path = "/nnat-ci/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_host}:aud" = "sts.amazonaws.com"
          "${local.oidc_host}:sub" = "repo:${var.github_repository}:pull_request"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "plan_read_only" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy" "plan_state" {
  name = "state-and-guards"
  role = aws_iam_role.plan.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(local.state_access_read, [{
      Sid      = "NeverReadSecretValues"
      Effect   = "Deny"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = "*"
    }])
  })
}

# Boundary for every role the stack creates. It is the ceiling of what a task or flow-log role may ever do,
# whatever policy is attached to it later.
resource "aws_iam_policy" "boundary" {
  #checkov:skip=CKV_AWS_288:A boundary is a ceiling, not a grant; the roles' own policies name their resources
  #checkov:skip=CKV_AWS_290:Same: the boundary only limits what the attached policies can allow
  #checkov:skip=CKV_AWS_355:Same: "*" here is the upper bound, narrowed by each role's own policy
  name = "${var.name_prefix}-boundary"
  path = "/nnat-ci/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "PullImagesAndWriteLogs"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:BatchCheckLayerAvailability", "logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
        Resource = "*"
      },
      {
        Sid      = "ReadApplicationSecrets"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "kms:Decrypt"]
        Resource = "*"
      },
    ]
  })
}

# Deploys: assumable only by jobs that run in the GitHub Environment of the same name, which is where
# required reviewers are configured. The policy lists the services the stack uses; resources are not
# narrowed further because Terraform creates new ones, so it is broad within those services. One policy per
# environment so that an environment's role can write only its own state.
#
# The CI roles and the boundary live under the IAM path /nnat-ci/, outside the /nnat/ path this policy may
# manage, so a deploy role cannot edit itself, another deploy role or the boundary.
resource "aws_iam_policy" "deploy" {
  #checkov:skip=CKV_AWS_289:Terraform must create and change resources in each listed service; narrowing to ARNs that do not exist yet is not possible
  #checkov:skip=CKV_AWS_290:Same reason: write access to the listed services is the purpose of the deploy role
  #checkov:skip=CKV_AWS_355:Resource "*" is needed for create actions on services without pre-existing ARNs; IAM is path-scoped below
  #checkov:skip=CKV_AWS_288:The deploy role may read secrets metadata and KMS to manage them; secret values are never output by the stack
  #checkov:skip=CKV_AWS_286:IAM actions are restricted to the /nnat/ path and to roles that carry the permissions boundary
  #checkov:skip=CKV_AWS_287:No credential exposure beyond managing the stack's own secrets
  for_each = var.environments

  name = "${var.name_prefix}-deploy-${each.key}"
  path = "/nnat-ci/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListOwnStatePrefix"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = [local.bucket_arn]
        Condition = {
          StringLike = { "s3:prefix" = ["${each.key}/*"] }
        }
      },
      {
        Sid      = "WriteOwnState"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = ["${local.bucket_arn}/${each.key}/terraform.tfstate"]
      },
      {
        Sid      = "LockOwnState"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = ["${local.bucket_arn}/${each.key}/terraform.tfstate.tflock"]
      },
      {
        Sid      = "UseStateKey"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = [aws_kms_key.state.arn]
      },
      {
        Sid      = "NeverDestroyTheStateKey"
        Effect   = "Deny"
        Action   = ["kms:ScheduleKeyDeletion", "kms:DisableKey", "kms:PutKeyPolicy"]
        Resource = [aws_kms_key.state.arn]
      },
      {
        Sid    = "ManageStackServices"
        Effect = "Allow"
        Action = [
          "ec2:*", "ecs:*", "ecr:*", "elasticloadbalancing:*", "rds:*", "elasticache:*", "logs:*",
          "cloudwatch:*", "sns:*", "secretsmanager:*", "kms:*", "acm:*", "route53:*",
        ]
        Resource = "*"
      },
      {
        Sid    = "ManageNnatRoles"
        Effect = "Allow"
        Action = [
          "iam:GetRole", "iam:DeleteRole", "iam:UpdateRole", "iam:TagRole", "iam:UntagRole", "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies", "iam:ListInstanceProfilesForRole", "iam:GetRolePolicy",
          "iam:UpdateAssumeRolePolicy", "iam:PassRole",
        ]
        Resource = [local.nnat_roles]
      },
      {
        Sid      = "ChangeRolePoliciesWithBoundary"
        Effect   = "Allow"
        Action   = ["iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:AttachRolePolicy", "iam:DetachRolePolicy"]
        Resource = [local.nnat_roles]
        Condition = {
          StringEquals = { "iam:PermissionsBoundary" = local.boundary_arn }
        }
      },
      {
        Sid      = "CreateRolesWithBoundary"
        Effect   = "Allow"
        Action   = ["iam:CreateRole", "iam:PutRolePermissionsBoundary"]
        Resource = [local.nnat_roles]
        Condition = {
          StringEquals = { "iam:PermissionsBoundary" = local.boundary_arn }
        }
      },
      {
        Sid      = "NeverRemoveTheBoundary"
        Effect   = "Deny"
        Action   = ["iam:DeleteRolePermissionsBoundary"]
        Resource = [local.nnat_roles]
      },
      {
        Sid      = "ServiceLinkedRoles"
        Effect   = "Allow"
        Action   = ["iam:CreateServiceLinkedRole"]
        Resource = ["arn:aws:iam::${local.account_id}:role/aws-service-role/*"]
        Condition = {
          StringEquals = {
            "iam:AWSServiceName" = [
              "ecs.amazonaws.com", "elasticloadbalancing.amazonaws.com", "rds.amazonaws.com", "elasticache.amazonaws.com",
            ]
          }
        }
      },
    ]
  })
}

resource "aws_iam_role" "deploy" {
  for_each = var.environments

  name = "${var.name_prefix}-ci-deploy-${each.key}"
  path = "/nnat-ci/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_host}:aud" = "sts.amazonaws.com"
          "${local.oidc_host}:sub" = "repo:${var.github_repository}:environment:${each.key}"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "deploy" {
  for_each = aws_iam_role.deploy

  role       = each.value.name
  policy_arn = aws_iam_policy.deploy[each.key].arn
}
