output "app_url" {
  description = "Public URL of the application (prod namespace)"
  value       = module.alb.app_url
}

output "jenkins_url" {
  description = "Jenkins UI (reachable only from admin_cidrs)"
  value       = module.alb.jenkins_url
}

output "alb_dns_name" {
  value = module.alb.dns_name
}

output "instance_ids" {
  description = "Instance IDs by role (connect with: aws ssm start-session --target <id>)"
  value       = module.compute.instance_ids
}

output "instance_private_ips" {
  value = module.compute.private_ips
}

output "ssm_bucket" {
  description = "Bucket used by the Ansible SSM connection plugin for file transfers"
  value       = module.compute.ssm_bucket
}

output "cloudwatch_dashboard_url" {
  value = module.monitoring.dashboard_url
}
