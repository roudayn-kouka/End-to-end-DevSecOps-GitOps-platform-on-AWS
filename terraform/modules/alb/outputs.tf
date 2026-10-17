output "security_group_id" {
  value = aws_security_group.alb.id
}

output "dns_name" {
  value = aws_lb.this.dns_name
}

output "alb_arn_suffix" {
  value = aws_lb.this.arn_suffix
}

output "app_target_group_arn" {
  value = aws_lb_target_group.app.arn
}

output "app_target_group_arn_suffix" {
  value = aws_lb_target_group.app.arn_suffix
}

output "jenkins_target_group_arn" {
  value = aws_lb_target_group.jenkins.arn
}

output "app_url" {
  value = local.https ? "https://${var.domain_name}" : "http://${aws_lb.this.dns_name}"
}

output "jenkins_url" {
  value = local.https ? "https://jenkins.${var.domain_name}" : "http://${aws_lb.this.dns_name}:8080"
}
