mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

# Computed ARNs are unknown in a plan, which would hide the policy documents from the assertions below.
override_resource {
  target          = aws_iam_openid_connect_provider.github
  override_during = plan
  values = {
    arn = "arn:aws:iam::111111111111:oidc-provider/token.actions.githubusercontent.com"
  }
}

override_resource {
  target          = aws_s3_bucket.state
  override_during = plan
  values = {
    arn = "arn:aws:s3:::example-nnat-terraform-state"
  }
}

override_resource {
  target          = aws_kms_key.state
  override_during = plan
  values = {
    arn = "arn:aws:kms:eu-central-1:111111111111:key/11111111-2222-3333-4444-555555555555"
  }
}

override_resource {
  target          = aws_iam_policy.boundary
  override_during = plan
  values = {
    arn = "arn:aws:iam::111111111111:policy/nnat-ci/nnat-boundary"
  }
}

variables {
  github_repository = "example/nest-next-aws-terraform"
  state_bucket_name = "example-nnat-terraform-state"
}

run "deploy_roles_are_per_environment" {
  command = plan

  assert {
    condition     = length(aws_iam_role.deploy) == 3
    error_message = "expected a deploy role for dev, stage and prod"
  }
}

run "deploy_trust_is_limited_to_the_github_environment" {
  command = plan

  assert {
    condition = alltrue([
      for env, r in aws_iam_role.deploy :
      jsondecode(r.assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:sub"] == "repo:example/nest-next-aws-terraform:environment:${env}"
    ])
    error_message = "each deploy role must trust exactly its GitHub environment"
  }
}

run "plan_role_trusts_pull_requests_only" {
  command = plan

  assert {
    condition     = jsondecode(aws_iam_role.plan.assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:sub"] == "repo:example/nest-next-aws-terraform:pull_request"
    error_message = "the plan role must be assumable from pull requests only"
  }
}

run "audience_is_always_sts" {
  command = plan

  assert {
    condition     = jsondecode(aws_iam_role.plan.assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:aud"] == "sts.amazonaws.com"
    error_message = "the OIDC audience must be sts.amazonaws.com"
  }
}

run "iam_actions_are_limited_to_the_nnat_path" {
  command = plan

  assert {
    condition = alltrue([
      for s in jsondecode(aws_iam_policy.deploy["dev"].policy).Statement :
      !startswith(tolist(s.Action)[0], "iam:") || s.Sid == "ServiceLinkedRoles" || alltrue([for r in flatten([s.Resource]) : strcontains(r, "/nnat/")])
    ])
    error_message = "IAM statements must name resources under /nnat/ (except service-linked roles)"
  }
}

run "role_creation_requires_the_boundary" {
  command = plan

  assert {
    condition     = anytrue([for s in jsondecode(aws_iam_policy.deploy["dev"].policy).Statement : s.Sid == "CreateRolesWithBoundary" && contains(keys(s.Condition.StringEquals), "iam:PermissionsBoundary")])
    error_message = "iam:CreateRole must be conditional on the permissions boundary"
  }
}

run "state_bucket_is_private_and_versioned" {
  command = plan

  assert {
    condition = (
      aws_s3_bucket_versioning.state.versioning_configuration[0].status == "Enabled"
      && aws_s3_bucket_public_access_block.state.block_public_acls == true
      && aws_s3_bucket_public_access_block.state.block_public_policy == true
      && aws_s3_bucket_public_access_block.state.ignore_public_acls == true
      && aws_s3_bucket_public_access_block.state.restrict_public_buckets == true
    )
    error_message = "the state bucket must be versioned and fully private"
  }
}

run "state_bucket_is_encrypted_with_kms" {
  command = plan

  assert {
    condition     = one(aws_s3_bucket_server_side_encryption_configuration.state.rule).apply_server_side_encryption_by_default[0].sse_algorithm == "aws:kms"
    error_message = "state must be encrypted with KMS"
  }
}

# Review finding C1: Terraform must be able to persist state, and only its own environment's.
run "deploy_role_can_write_only_its_own_state" {
  command = plan

  assert {
    condition = (
      anytrue([for s in jsondecode(aws_iam_policy.deploy["dev"].policy).Statement : s.Sid == "WriteOwnState" && contains(tolist(s.Action), "s3:PutObject") && contains(tolist(s.Resource), "arn:aws:s3:::example-nnat-terraform-state/dev/terraform.tfstate")])
      && !anytrue([for s in jsondecode(aws_iam_policy.deploy["dev"].policy).Statement : strcontains(jsonencode(s), "/prod/") || strcontains(jsonencode(s), "/stage/")])
    )
    error_message = "the dev deploy role must write dev state and nothing of prod or stage"
  }
}

# Review finding C2: the deploy role must not be able to edit the CI roles or the boundary.
run "ci_roles_and_boundary_are_outside_the_stack_iam_path" {
  command = plan

  assert {
    condition     = aws_iam_role.plan.path == "/nnat-ci/" && alltrue([for r in aws_iam_role.deploy : r.path == "/nnat-ci/"]) && aws_iam_policy.boundary.path == "/nnat-ci/" && alltrue([for p in aws_iam_policy.deploy : p.path == "/nnat-ci/"])
    error_message = "CI roles and policies must not live under /nnat/, which the deploy role manages"
  }
}

run "role_policy_changes_require_the_boundary" {
  command = plan

  assert {
    condition = anytrue([
      for s in jsondecode(aws_iam_policy.deploy["dev"].policy).Statement :
      contains(tolist(s.Action), "iam:AttachRolePolicy") && contains(tolist(s.Action), "iam:PutRolePolicy") && s.Condition.StringEquals["iam:PermissionsBoundary"] == "arn:aws:iam::111111111111:policy/nnat-ci/nnat-boundary"
    ])
    error_message = "attaching or putting role policies must require the permissions boundary"
  }
}

run "deploy_role_cannot_manage_managed_policies" {
  command = plan

  assert {
    condition     = !anytrue([for s in jsondecode(aws_iam_policy.deploy["dev"].policy).Statement : anytrue([for a in tolist(s.Action) : strcontains(a, "iam:CreatePolicy") || strcontains(a, "iam:DeletePolicy")])])
    error_message = "the stack creates no managed policies, so the deploy role must not be able to rewrite any (the boundary included)"
  }
}

# Review finding I8: a deploy role must not be able to destroy the state key.
run "state_key_cannot_be_destroyed_by_the_deploy_role" {
  command = plan

  assert {
    condition     = anytrue([for s in jsondecode(aws_iam_policy.deploy["dev"].policy).Statement : s.Effect == "Deny" && contains(tolist(s.Action), "kms:ScheduleKeyDeletion") && contains(tolist(s.Action), "kms:PutKeyPolicy")])
    error_message = "deny destructive KMS actions on the state key"
  }
}
