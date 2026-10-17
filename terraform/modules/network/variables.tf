variable "name" {
  description = "Name prefix"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC (a /16 is expected: subnets are carved as /24)"
  type        = string
}

variable "availability_zones" {
  description = "Availability zones; one public and one private subnet is created in each"
  type        = list(string)
}
