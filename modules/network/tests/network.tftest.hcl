mock_provider "aws" {
  # Mocked data sources return random strings; IAM resources validate their policy as JSON.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  override_data {
    target = data.aws_availability_zones.available
    values = {
      names = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
    }
  }
}

variables {
  name_prefix = "nnat-test"
}

run "single_nat_by_default" {
  command = plan

  assert {
    condition     = output.nat_gateway_count == 1
    error_message = "nat_mode single must create one NAT gateway"
  }
}

run "one_nat_per_az" {
  command = plan

  variables {
    nat_mode = "per_az"
    az_count = 2
  }

  assert {
    condition     = output.nat_gateway_count == 2
    error_message = "nat_mode per_az must create one NAT gateway per AZ"
  }
}

run "subnets_follow_az_count" {
  command = plan

  variables {
    az_count = 3
  }

  assert {
    condition     = length(aws_subnet.public) == 3 && length(aws_subnet.private) == 3
    error_message = "expected a public and a private subnet per AZ"
  }
}

run "private_subnets_do_not_get_public_ips" {
  command = plan

  assert {
    condition     = alltrue([for s in aws_subnet.private : s.map_public_ip_on_launch == false])
    error_message = "private subnets must not assign public IPs"
  }
}

run "unknown_nat_mode_is_rejected" {
  command = plan

  variables {
    nat_mode = "bad"
  }

  expect_failures = [var.nat_mode]
}

run "flow_log_role_carries_the_permissions_boundary_when_given" {
  command = plan

  variables {
    permissions_boundary_arn = "arn:aws:iam::111111111111:policy/nnat/nnat-boundary"
  }

  assert {
    condition     = aws_iam_role.flow.permissions_boundary == "arn:aws:iam::111111111111:policy/nnat/nnat-boundary"
    error_message = "the flow log role must carry the boundary"
  }
}
