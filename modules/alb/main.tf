locals {
  https           = var.domain_name != ""
  default_name    = one([for name, tg in var.target_groups : name if length(tg.path_patterns) == 0])
  routed          = { for name, tg in var.target_groups : name => tg if length(tg.path_patterns) > 0 }
  main_listener   = local.https ? aws_lb_listener.https[0].arn : aws_lb_listener.http.arn
  public_hostname = local.https ? var.domain_name : aws_lb.this.dns_name
}

resource "aws_security_group" "this" {
  name        = "${var.name_prefix}-alb"
  description = "Public HTTP and HTTPS entry point"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name_prefix}-alb" }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  #checkov:skip=CKV_AWS_260:The load balancer is the public entry point; port 80 is open to redirect to HTTPS (or to serve dev over HTTP)
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  description       = "HTTP from the internet"
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  count = local.https ? 1 : 0

  security_group_id = aws_security_group.this.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "HTTPS from the internet"
}

resource "aws_vpc_security_group_egress_rule" "to_vpc" {
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "-1"
  description       = "Traffic to the application tasks inside the VPC"
}

resource "aws_lb" "this" {
  #checkov:skip=CKV_AWS_91:Access logs need an S3 bucket and cost money; they are an operator decision, see the cost guide
  #checkov:skip=CKV2_AWS_28:A WAF costs a fixed monthly fee; it is listed as an optional later mitigation in ADR 0006
  #checkov:skip=CKV2_AWS_20:The redirect exists when a domain is set; without one there is no certificate to redirect to
  #checkov:skip=CKV_AWS_150:Deletion protection is the deletion_protection variable; prod sets it
  name                       = "${var.name_prefix}-alb"
  load_balancer_type         = "application"
  internal                   = false
  subnets                    = var.public_subnet_ids
  security_groups            = [aws_security_group.this.id]
  drop_invalid_header_fields = true
  enable_deletion_protection = var.deletion_protection
}

resource "aws_lb_target_group" "this" {
  #checkov:skip=CKV_AWS_378:The starter's containers do not terminate TLS; the ALB encrypts the public side and traffic stays inside the VPC
  for_each = var.target_groups

  name                 = "${var.name_prefix}-${each.key}"
  vpc_id               = var.vpc_id
  port                 = each.value.port
  protocol             = "HTTP"
  target_type          = "ip"
  deregistration_delay = var.deregistration_delay

  health_check {
    path                = each.value.health_path
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "http" {
  #checkov:skip=CKV_AWS_2:Without a domain there is no certificate, so the listener serves HTTP; with a domain it only redirects
  #checkov:skip=CKV_AWS_103:Applies to HTTPS listeners; this one serves HTTP or redirects
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  dynamic "default_action" {
    for_each = local.https ? [1] : []

    content {
      type = "redirect"

      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  dynamic "default_action" {
    for_each = local.https ? [] : [1]

    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.this[local.default_name].arn
    }
  }
}

resource "aws_lb_listener" "https" {
  count = local.https ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.this[0].certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[local.default_name].arn
  }
}

resource "aws_lb_listener_rule" "routed" {
  for_each = local.routed

  listener_arn = local.main_listener
  priority     = each.value.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[each.key].arn
  }

  condition {
    path_pattern {
      values = each.value.path_patterns
    }
  }
}

resource "aws_acm_certificate" "this" {
  count = local.https ? 1 : 0

  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# One name, no SANs, so exactly one validation record. A static count also keeps the plan valid before the
# certificate exists (domain_validation_options is unknown until apply).
resource "aws_route53_record" "validation" {
  count = local.https ? 1 : 0

  zone_id         = var.hosted_zone_id
  name            = tolist(aws_acm_certificate.this[0].domain_validation_options)[0].resource_record_name
  type            = tolist(aws_acm_certificate.this[0].domain_validation_options)[0].resource_record_type
  records         = [tolist(aws_acm_certificate.this[0].domain_validation_options)[0].resource_record_value]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "this" {
  count = local.https ? 1 : 0

  certificate_arn         = aws_acm_certificate.this[0].arn
  validation_record_fqdns = [aws_route53_record.validation[0].fqdn]
}

resource "aws_route53_record" "alias" {
  count = local.https ? 1 : 0

  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = true
  }
}
