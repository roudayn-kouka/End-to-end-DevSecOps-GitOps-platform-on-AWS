variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "nodes" {
  description = "Nodes keyed by role: jenkins-master, jenkins-agent, k8s-master, k8s-worker"
  type = map(object({
    instance_type = string
    disk_size_gb  = number
  }))
}

variable "alb_sg_id" {
  description = "Security group of the ALB, allowed to reach Jenkins and the ingress NodePort"
  type        = string
}

variable "ingress_node_port" {
  type = number
}
