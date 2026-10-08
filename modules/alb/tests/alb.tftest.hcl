mock_provider "aws" {}

variables {
  name_prefix       = "nnat-test"
  vpc_id            = "vpc-0123456789abcdef0"
  vpc_cidr          = "10.0.0.0/16"
  public_subnet_ids = ["subnet-aaa", "subnet-bbb"]
  target_groups = {
    api = { port = 4000, health_path = "/api/health/ready", path_patterns = ["/api/*"], priority = 10 }
    web = { port = 3000, health_path = "/sign-in", path_patterns = [], priority = 0 }
  }
}

run "without_a_domain_there_is_one_http_listener" {
  command = plan

  assert {
    condition     = length(aws_lb_listener.https) == 0 && length(aws_acm_certificate.this) == 0 && output.https_enabled == false
    error_message = "no domain means HTTP only and no certificate"
  }
}

run "without_a_domain_forward_to_the_default_group" {
  command = plan

  assert {
    condition     = aws_lb_listener.http.default_action[0].type == "forward"
    error_message = "the HTTP listener must forward when there is no HTTPS"
  }
}

run "with_a_domain_https_uses_tls13_policy_and_http_redirects" {
  command = plan

  variables {
    domain_name    = "app.example.com"
    hosted_zone_id = "Z0000000000000000000"
  }

  assert {
    condition     = aws_lb_listener.https[0].ssl_policy == "ELBSecurityPolicy-TLS13-1-2-2021-06" && aws_lb_listener.http.default_action[0].type == "redirect" && output.https_enabled == true
    error_message = "HTTPS must use the TLS 1.3 policy and HTTP must redirect"
  }
}

run "with_a_domain_the_origin_is_https" {
  command = plan

  variables {
    domain_name    = "app.example.com"
    hosted_zone_id = "Z0000000000000000000"
  }

  assert {
    condition     = output.public_origin == "https://app.example.com"
    error_message = "public_origin must be the https domain"
  }
}

run "a_domain_needs_a_hosted_zone" {
  command = plan

  variables {
    domain_name = "app.example.com"
  }

  expect_failures = [var.hosted_zone_id]
}

run "exactly_one_target_group_is_the_default" {
  command = plan

  variables {
    target_groups = {
      api = { port = 4000, health_path = "/", path_patterns = ["/api/*"], priority = 10 }
    }
  }

  expect_failures = [var.target_groups]
}

run "invalid_headers_are_dropped" {
  command = plan

  assert {
    condition     = aws_lb.this.drop_invalid_header_fields == true
    error_message = "drop_invalid_header_fields must be on"
  }
}
