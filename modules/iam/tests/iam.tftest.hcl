mock_provider "aws" {}

variables {
  name_prefix     = "nnat-test"
  services        = ["api", "web"]
  secret_arns     = ["arn:aws:secretsmanager:eu-central-1:111111111111:secret:nnat-test/database-url-AbCdEf"]
  repository_arns = ["arn:aws:ecr:eu-central-1:111111111111:repository/nnat-test/api"]
  log_group_arns  = ["arn:aws:logs:eu-central-1:111111111111:log-group:/nnat-test/api"]
}

run "secret_read_is_limited_to_the_given_arns" {
  command = plan

  assert {
    condition = anytrue([
      for s in jsondecode(aws_iam_role_policy.execution.policy).Statement :
      s.Sid == "ReadSecrets" && tolist(s.Resource) == var.secret_arns && tolist(s.Action) == tolist(["secretsmanager:GetSecretValue"])
    ])
    error_message = "ReadSecrets must name exactly the secret ARNs"
  }
}

run "only_ecr_authorization_uses_a_wildcard" {
  command = plan

  assert {
    condition = alltrue([
      for s in jsondecode(aws_iam_role_policy.execution.policy).Statement :
      s.Sid == "EcrAuthorization" || !contains(flatten([s.Resource]), "*")
    ])
    error_message = "ecr:GetAuthorizationToken is the only action that may use a wildcard resource"
  }
}

run "one_task_role_per_service" {
  command = plan

  assert {
    condition     = length(aws_iam_role.task) == 2
    error_message = "expected one task role per service"
  }
}

run "roles_live_under_the_nnat_path" {
  command = plan

  assert {
    condition     = aws_iam_role.execution.path == "/nnat/" && alltrue([for r in aws_iam_role.task : r.path == "/nnat/"])
    error_message = "every role must be under /nnat/ so the deploy role can be scoped to it"
  }
}

run "kms_decrypt_statement_appears_only_with_keys" {
  command = plan

  assert {
    condition     = !anytrue([for s in jsondecode(aws_iam_role_policy.execution.policy).Statement : s.Sid == "DecryptSecrets"])
    error_message = "no kms statement without key ARNs"
  }
}

run "kms_decrypt_statement_names_the_keys" {
  command = plan

  variables {
    kms_key_arns = ["arn:aws:kms:eu-central-1:111111111111:key/11111111-2222-3333-4444-555555555555"]
  }

  assert {
    condition     = anytrue([for s in jsondecode(aws_iam_role_policy.execution.policy).Statement : s.Sid == "DecryptSecrets" && tolist(s.Resource) == var.kms_key_arns])
    error_message = "DecryptSecrets must name the key ARNs"
  }
}

run "roles_carry_the_permissions_boundary_when_given" {
  command = plan

  variables {
    permissions_boundary_arn = "arn:aws:iam::111111111111:policy/nnat/nnat-boundary"
  }

  assert {
    condition     = aws_iam_role.execution.permissions_boundary == "arn:aws:iam::111111111111:policy/nnat/nnat-boundary" && alltrue([for r in aws_iam_role.task : r.permissions_boundary == "arn:aws:iam::111111111111:policy/nnat/nnat-boundary"])
    error_message = "every role must carry the boundary the deploy role demands"
  }
}
