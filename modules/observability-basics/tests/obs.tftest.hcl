mock_provider "aws" {}

variables {
  name_prefix               = "nnat-test"
  log_groups                = ["api", "web", "migrate"]
  alarmed_services          = ["api", "web"]
  retention_days            = 30
  cluster_name              = "nnat-test"
  alb_arn_suffix            = "app/nnat-test-alb/0123456789abcdef"
  target_group_arn_suffixes = { api = "targetgroup/nnat-test-api/0123456789abcdef", web = "targetgroup/nnat-test-web/fedcba9876543210" }
  rds_instance_id           = "nnat-test-postgres"
}

run "log_groups_exist_with_retention" {
  command = plan

  assert {
    condition     = length(aws_cloudwatch_log_group.this) == 3 && alltrue([for g in aws_cloudwatch_log_group.this : g.retention_in_days == 30])
    error_message = "expected api, web and migrate log groups with the configured retention"
  }
}

run "log_group_names_match_the_ecs_convention" {
  command = plan

  assert {
    condition     = output.log_group_names["api"] == "/nnat-test/api"
    error_message = "log groups are /<name_prefix>/<name>"
  }
}

run "no_email_means_no_subscription" {
  command = plan

  assert {
    condition     = length(aws_sns_topic_subscription.email) == 0
    error_message = "a subscription must need an alarm_email"
  }
}

run "email_creates_a_subscription" {
  command = plan

  variables {
    alarm_email = "ops@example.com"
  }

  assert {
    condition     = length(aws_sns_topic_subscription.email) == 1
    error_message = "alarm_email must create one subscription"
  }
}

run "alarms_cover_load_balancer_services_and_database" {
  command = plan

  assert {
    condition = (
      aws_cloudwatch_metric_alarm.alb_5xx.alarm_name == "nnat-test-alb-5xx"
      && length(aws_cloudwatch_metric_alarm.target_5xx) == 2
      && length(aws_cloudwatch_metric_alarm.ecs_cpu) == 2
      && length(aws_cloudwatch_metric_alarm.ecs_memory) == 2
      && length(aws_cloudwatch_metric_alarm.running_tasks) == 2
      && aws_cloudwatch_metric_alarm.rds_storage.alarm_name == "nnat-test-rds-storage-low"
      && aws_cloudwatch_metric_alarm.rds_cpu.alarm_name == "nnat-test-rds-cpu-high"
    )
    error_message = "missing alarms"
  }
}

run "storage_alarm_threshold_is_in_bytes" {
  command = plan

  variables {
    rds_free_storage_gib = 5
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.rds_storage.threshold == 5368709120
    error_message = "FreeStorageSpace is reported in bytes"
  }
}
