mock_provider "aws" {}

variables {
  name_prefix        = "nnat-test"
  name               = "api"
  cluster_arn        = "arn:aws:ecs:eu-central-1:111111111111:cluster/nnat-test"
  image              = "111111111111.dkr.ecr.eu-central-1.amazonaws.com/nnat-test/api:abc123"
  enabled            = true
  cpu                = 256
  memory             = 512
  port               = 4000
  desired_count      = 1
  execution_role_arn = "arn:aws:iam::111111111111:role/nnat/nnat-test-ecs-execution"
  task_role_arn      = "arn:aws:iam::111111111111:role/nnat/nnat-test-task-api"
  subnet_ids         = ["subnet-aaa", "subnet-bbb"]
  vpc_id             = "vpc-0123456789abcdef0"
  log_group_name     = "/nnat-test/api"
  environment        = { APP_ENV = "prod", PORT = "4000" }
  secrets            = { DATABASE_URL = "arn:aws:secretsmanager:eu-central-1:111111111111:secret:nnat-test/database-url-AbCdEf" }
  health_command     = ["node", "-e", "process.exit(0)"]
}

run "disabled_plans_nothing_to_run" {
  command = plan

  variables {
    enabled = false
  }

  assert {
    condition     = length(aws_ecs_task_definition.this) == 0 && length(aws_ecs_service.this) == 0
    error_message = "a disabled module must not plan a task definition or a service"
  }
}

run "one_off_task_has_no_service" {
  command = plan

  variables {
    create_service = false
  }

  assert {
    condition     = length(aws_ecs_task_definition.this) == 1 && length(aws_ecs_service.this) == 0
    error_message = "create_service = false must plan only the task definition"
  }
}

run "service_rolls_back_on_failure" {
  command = plan

  assert {
    condition     = aws_ecs_service.this[0].deployment_circuit_breaker[0].rollback == true && aws_ecs_service.this[0].wait_for_steady_state == true
    error_message = "deployments must roll back and the apply must wait for a steady state"
  }
}

run "secrets_are_references_never_values" {
  command = plan

  assert {
    condition = (
      length(jsondecode(aws_ecs_task_definition.this[0].container_definitions)[0].secrets) == 1
      && jsondecode(aws_ecs_task_definition.this[0].container_definitions)[0].secrets[0].name == "DATABASE_URL"
      && startswith(jsondecode(aws_ecs_task_definition.this[0].container_definitions)[0].secrets[0].valueFrom, "arn:aws:secretsmanager:")
      && !contains([for e in jsondecode(aws_ecs_task_definition.this[0].container_definitions)[0].environment : e.name], "DATABASE_URL")
    )
    error_message = "secrets must be injected as valueFrom ARNs and not appear in environment"
  }
}

run "root_filesystem_stays_writable_for_nextjs" {
  command = plan

  assert {
    condition     = jsondecode(aws_ecs_task_definition.this[0].container_definitions)[0].readonlyRootFilesystem == false
    error_message = "the Next.js standalone server writes to .next/cache"
  }
}

run "alb_ingress_only_when_registered" {
  command = plan

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.from_alb) == 0
    error_message = "without register_with_alb there is no ingress rule"
  }
}

run "registered_service_accepts_the_alb_only" {
  command = plan

  variables {
    register_with_alb     = true
    target_group_arn      = "arn:aws:elasticloadbalancing:eu-central-1:111111111111:targetgroup/nnat-test-api/0123456789abcdef"
    alb_security_group_id = "sg-0123456789abcdef0"
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.from_alb) == 1 && one([for lb in aws_ecs_service.this[0].load_balancer : lb.container_port]) == 4000
    error_message = "a registered service needs an ALB ingress rule and a load balancer block"
  }
}

run "command_override_is_passed_to_the_container" {
  command = plan

  variables {
    name           = "migrate"
    create_service = false
    port           = 0
    health_command = []
    command        = ["node", "node_modules/typeorm/cli.js", "migration:run"]
  }

  assert {
    condition     = jsondecode(aws_ecs_task_definition.this[0].container_definitions)[0].command[0] == "node" && !contains(keys(jsondecode(aws_ecs_task_definition.this[0].container_definitions)[0]), "healthCheck")
    error_message = "the migration task overrides the command and has no health check"
  }
}
