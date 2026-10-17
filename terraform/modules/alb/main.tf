# Public Application Load Balancer: the only internet-facing entry point.
#
#   HTTP mode  (no domain): :80   -> ingress-nginx NodePort (application)
#                           :8080 -> Jenkins (admin_cidrs only)
#   HTTPS mode (domain set): :80 -> redirect to :443
#                           :443 -> application, jenkins.<domain> -> Jenkins (admin_cidrs only)

locals {
  https = var.domain_name != ""
}

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb"
  description = "Public load balancer"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-alb" }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from the internet"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  count = local.https ? 1 : 0

  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from the internet"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "jenkins" {
  for_each = local.https ? toset([]) : toset(var.admin_cidrs)

  security_group_id = aws_security_group.alb.id
  description       = "Jenkins UI from admin networks"
  cidr_ipv4         = each.value
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "to_vpc" {
  security_group_id = aws_security_group.alb.id
  description       = "Forward to targets inside the VPC"
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "-1"
}

resource "aws_lb" "this" {
  name                       = "${var.name}-alb"
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = var.public_subnet_ids
  drop_invalid_header_fields = true
}

resource "aws_lb_target_group" "app" {
  name     = "${var.name}-app"
  port     = var.ingress_node_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/healthz"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
  }
}

resource "aws_lb_target_group" "jenkins" {
  name     = "${var.name}-jenkins"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path    = "/login"
    matcher = "200"
  }
}

# ---------------------------------------------------------------- HTTP mode
resource "aws_lb_listener" "http_app" {
  count = local.https ? 0 : 1

  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_lb_listener" "http_jenkins" {
  count = local.https ? 0 : 1

  load_balancer_arn = aws_lb.this.arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkins.arn
  }
}

# --------------------------------------------------------------- HTTPS mode
data "aws_route53_zone" "this" {
  count = local.https ? 1 : 0
  name  = var.route53_zone_name
}

resource "aws_acm_certificate" "this" {
  count = local.https ? 1 : 0

  domain_name               = var.domain_name
  subject_alternative_names = ["dev.${var.domain_name}", "jenkins.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "validation" {
  for_each = local.https ? {
    for dvo in aws_acm_certificate.this[0].domain_validation_options : dvo.domain_name => dvo
  } : {}

  zone_id         = data.aws_route53_zone.this[0].zone_id
  name            = each.value.resource_record_name
  type            = each.value.resource_record_type
  records         = [each.value.resource_record_value]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "this" {
  count = local.https ? 1 : 0

  certificate_arn         = aws_acm_certificate.this[0].arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]
}

resource "aws_lb_listener" "redirect" {
  count = local.https ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
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
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_lb_listener_rule" "jenkins" {
  count = local.https ? 1 : 0

  listener_arn = aws_lb_listener.https[0].arn
  priority     = 10

  condition {
    host_header {
      values = ["jenkins.${var.domain_name}"]
    }
  }

  condition {
    source_ip {
      values = var.admin_cidrs
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkins.arn
  }
}

resource "aws_route53_record" "alias" {
  for_each = local.https ? toset([var.domain_name, "dev.${var.domain_name}", "jenkins.${var.domain_name}"]) : toset([])

  zone_id = data.aws_route53_zone.this[0].zone_id
  name    = each.value
  type    = "A"

  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = true
  }
}
