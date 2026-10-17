variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix used for every resource name"
  type        = string
  default     = "skyforge"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.project_name))
    error_message = "project_name must be 3-21 lowercase alphanumeric characters or dashes."
  }
}

variable "environment" {
  description = "Environment tag (the cluster hosts both the dev and prod namespaces)"
  type        = string
  default     = "lab"
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "availability_zones" {
  description = "Two availability zones (the ALB needs at least two)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least two availability zones are required."
  }
}

variable "admin_cidrs" {
  description = "CIDRs allowed to reach Jenkins through the ALB (e.g. your public IP /32)"
  type        = list(string)

  validation {
    condition     = !contains(var.admin_cidrs, "0.0.0.0/0")
    error_message = "Do not expose Jenkins to the whole internet: use your own IP (curl ifconfig.me)/32."
  }
}

variable "nodes" {
  description = "EC2 nodes of the platform, keyed by role"
  type = map(object({
    instance_type = string
    disk_size_gb  = number
  }))
  default = {
    jenkins-master = { instance_type = "t3.medium", disk_size_gb = 30 }
    jenkins-agent  = { instance_type = "t3.medium", disk_size_gb = 40 }
    k8s-master     = { instance_type = "t3.medium", disk_size_gb = 30 }
    k8s-worker     = { instance_type = "t3.large", disk_size_gb = 40 }
  }

  validation {
    condition = alltrue([
      for role in ["jenkins-master", "jenkins-agent", "k8s-master", "k8s-worker"] : contains(keys(var.nodes), role)
    ])
    error_message = "nodes must define jenkins-master, jenkins-agent, k8s-master and k8s-worker."
  }
}

variable "ingress_node_port" {
  description = "NodePort exposed by ingress-nginx inside the cluster (must match argocd/platform/ingress-nginx.yaml)"
  type        = number
  default     = 30080
}

variable "domain_name" {
  description = "Optional Route53 domain (e.g. skyforge.example.com). Enables HTTPS with ACM. Leave empty for HTTP only."
  type        = string
  default     = ""
}

variable "route53_zone_name" {
  description = "Public hosted zone that contains domain_name (e.g. example.com). Required when domain_name is set."
  type        = string
  default     = ""
}

variable "alert_email" {
  description = "Email subscribed to CloudWatch alarms and budget alerts (confirm the subscription email)"
  type        = string
  default     = ""
}

variable "monthly_budget_usd" {
  description = "Monthly AWS budget; an alert fires at 80% (forecast) and 100% (actual)"
  type        = number
  default     = 50
}
