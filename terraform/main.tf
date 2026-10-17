module "network" {
  source = "./modules/network"

  name               = var.project_name
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}

module "alb" {
  source = "./modules/alb"

  name              = var.project_name
  vpc_id            = module.network.vpc_id
  vpc_cidr          = var.vpc_cidr
  public_subnet_ids = module.network.public_subnet_ids
  admin_cidrs       = var.admin_cidrs
  ingress_node_port = var.ingress_node_port
  domain_name       = var.domain_name
  route53_zone_name = var.route53_zone_name
}

module "compute" {
  source = "./modules/compute"

  name               = var.project_name
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
  nodes              = var.nodes
  alb_sg_id          = module.alb.security_group_id
  ingress_node_port  = var.ingress_node_port
}

# Register the nodes behind the ALB target groups.
resource "aws_lb_target_group_attachment" "jenkins" {
  target_group_arn = module.alb.jenkins_target_group_arn
  target_id        = module.compute.instance_ids["jenkins-master"]
  port             = 8080
}

resource "aws_lb_target_group_attachment" "ingress" {
  for_each = toset(["k8s-master", "k8s-worker"])

  target_group_arn = module.alb.app_target_group_arn
  target_id        = module.compute.instance_ids[each.key]
  port             = var.ingress_node_port
}

module "monitoring" {
  source = "./modules/monitoring"

  name               = var.project_name
  aws_region         = var.aws_region
  instance_ids       = module.compute.instance_ids
  alb_arn_suffix     = module.alb.alb_arn_suffix
  app_tg_arn_suffix  = module.alb.app_target_group_arn_suffix
  alert_email        = var.alert_email
  monthly_budget_usd = var.monthly_budget_usd
}
