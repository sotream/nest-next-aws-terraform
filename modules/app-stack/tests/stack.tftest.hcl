# The AWS provider is mocked; the random provider is real because mock providers cannot serve the ephemeral
# passwords. No call leaves the machine.
mock_provider "aws" {
  override_data {
    target = module.network.data.aws_availability_zones.available
    values = {
      names = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  environment    = "dev"
  hosted_zone_id = "Z0000000000000000000"
}

run "prod_requires_a_domain" {
  command = plan

  variables {
    environment = "prod"
    domain_name = ""
  }

  expect_failures = [terraform_data.guard]
}

run "stage_requires_a_domain" {
  command = plan

  variables {
    environment = "stage"
    domain_name = ""
  }

  expect_failures = [terraform_data.guard]
}

run "dev_without_a_domain_is_http_and_app_env_dev" {
  command = plan

  assert {
    condition     = output.app_env == "dev" && startswith(output.public_origin, "http://")
    error_message = "dev without a domain must run APP_ENV=dev over http"
  }
}

run "any_environment_with_a_domain_is_prod_over_https" {
  command = plan

  variables {
    environment = "stage"
    domain_name = "stage.example.com"
  }

  assert {
    condition     = output.app_env == "prod" && output.public_origin == "https://stage.example.com"
    error_message = "a domain means APP_ENV=prod and an https origin"
  }
}

run "first_deploy_has_no_services_and_no_migration" {
  command = plan

  assert {
    condition     = module.api.service_name == null && module.web.service_name == null && output.migrate_task_definition_arn == null
    error_message = "with empty image tags nothing runs and there is no migration task definition"
  }
}

# That the migration task definition itself appears is covered by the ecs-service tests: its ARN is unknown
# in a plan and mocked applies produce invalid ARNs, so it cannot be asserted here.
run "migration_image_tag_does_not_start_the_services" {
  command = plan

  variables {
    migrate_image_tag = "abc123def456"
  }

  assert {
    condition     = module.web.service_name == null && module.api.service_name == null
    error_message = "registering the migration task must not start the services"
  }
}

run "services_start_when_the_image_tag_is_set" {
  command = plan

  variables {
    migrate_image_tag  = "abc123def456"
    services_image_tag = "abc123def456"
  }

  assert {
    condition     = module.api.service_name == "nnat-dev-api" && module.web.service_name == "nnat-dev-web"
    error_message = "a services image tag must create both services"
  }
}
