data "aws_region" "current" {}

locals {
  service_name = "${var.name_prefix}-${var.name}"

  container = merge(
    {
      name                   = var.name
      image                  = var.image
      essential              = true
      readonlyRootFilesystem = false # the Next.js standalone server writes to .next/cache; see ADR 0001
      environment            = [for k, v in var.environment : { name = k, value = v }]
      secrets                = [for k, arn in var.secrets : { name = k, valueFrom = arn }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.log_group_name
          awslogs-region        = data.aws_region.current.region
          awslogs-stream-prefix = var.name
        }
      }
    },
    var.port > 0 ? { portMappings = [{ containerPort = var.port, protocol = "tcp" }] } : {},
    length(var.command) > 0 ? { command = var.command } : {},
    length(var.health_command) > 0 ? {
      healthCheck = {
        command     = concat(["CMD"], var.health_command)
        interval    = 15
        timeout     = 5
        retries     = 3
        startPeriod = 20
      }
    } : {},
  )
}

resource "aws_security_group" "this" {
  name        = local.service_name
  description = "${local.service_name} tasks"
  vpc_id      = var.vpc_id

  tags = { Name = local.service_name }
}

resource "aws_vpc_security_group_ingress_rule" "from_alb" {
  count = var.register_with_alb ? 1 : 0

  security_group_id            = aws_security_group.this.id
  referenced_security_group_id = var.alb_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = var.port
  to_port                      = var.port
  description                  = "Traffic from the load balancer"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  #checkov:skip=CKV_AWS_382:Tasks reach ECR, Secrets Manager and CloudWatch through the NAT, and the database and cache inside the VPC; destinations are AWS public endpoints
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Outbound through the NAT and inside the VPC"
}

resource "aws_ecs_task_definition" "this" {
  count = var.enabled ? 1 : 0

  family                   = local.service_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([local.container])
}

resource "aws_ecs_service" "this" {
  count = var.enabled && var.create_service ? 1 : 0

  name            = local.service_name
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.this[0].arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  wait_for_steady_state              = true
  enable_execute_command             = false
  propagate_tags                     = "SERVICE"
  health_check_grace_period_seconds  = var.register_with_alb ? var.health_check_grace_period_seconds : null

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.this.id]
    assign_public_ip = false
  }

  dynamic "load_balancer" {
    for_each = var.register_with_alb ? [1] : []

    content {
      target_group_arn = var.target_group_arn
      container_name   = var.name
      container_port   = var.port
    }
  }
}
