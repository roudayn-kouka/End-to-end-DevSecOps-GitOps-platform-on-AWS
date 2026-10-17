variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "admin_cidrs" {
  description = "Networks allowed to reach Jenkins"
  type        = list(string)
}

variable "ingress_node_port" {
  type = number
}

variable "domain_name" {
  description = "Enables HTTPS mode when non-empty"
  type        = string
  default     = ""
}

variable "route53_zone_name" {
  type    = string
  default = ""

  validation {
    condition     = var.route53_zone_name != "" || var.domain_name == ""
    error_message = "route53_zone_name is required when domain_name is set."
  }
}
