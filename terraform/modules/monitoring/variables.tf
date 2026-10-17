variable "name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "instance_ids" {
  description = "Instance IDs keyed by role"
  type        = map(string)
}

variable "alb_arn_suffix" {
  type = string
}

variable "app_tg_arn_suffix" {
  type = string
}

variable "alert_email" {
  type    = string
  default = ""
}

variable "monthly_budget_usd" {
  type = number
}
