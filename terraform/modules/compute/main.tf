# Private EC2 nodes managed through SSM Session Manager (no SSH key, no public IP, port 22 closed).

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  k8s_nodes = toset(["k8s-master", "k8s-worker"])
}

# ------------------------------------------------------------------ IAM / SSM
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.name}-node"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Bucket used by Ansible's aws_ssm connection plugin to transfer files.
resource "aws_s3_bucket" "ssm" {
  bucket        = "${var.name}-ssm-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "ssm" {
  bucket                  = aws_s3_bucket.ssm.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ssm" {
  bucket = aws_s3_bucket.ssm.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "ssm" {
  bucket = aws_s3_bucket.ssm.id
  rule {
    id     = "expire-transfers"
    status = "Enabled"
    filter {}
    expiration {
      days = 1
    }
  }
}

data "aws_iam_policy_document" "ssm_bucket" {
  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.ssm.arn}/*"]
  }
  statement {
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [aws_s3_bucket.ssm.arn]
  }
}

resource "aws_iam_role_policy" "ssm_bucket" {
  name   = "ansible-ssm-transfer"
  role   = aws_iam_role.node.id
  policy = data.aws_iam_policy_document.ssm_bucket.json
}

resource "aws_iam_instance_profile" "node" {
  name = "${var.name}-node"
  role = aws_iam_role.node.name
}

# ------------------------------------------------------------ Security groups
resource "aws_security_group" "jenkins" {
  name        = "${var.name}-jenkins"
  description = "Jenkins controller and build agent"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-jenkins" }
}

resource "aws_vpc_security_group_ingress_rule" "jenkins_ui_from_alb" {
  security_group_id            = aws_security_group.jenkins.id
  description                  = "Jenkins UI through the ALB"
  referenced_security_group_id = var.alb_sg_id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "jenkins_agent_ssh" {
  security_group_id            = aws_security_group.jenkins.id
  description                  = "Controller launches the agent over SSH"
  referenced_security_group_id = aws_security_group.jenkins.id
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
}

resource "aws_security_group" "k8s" {
  name        = "${var.name}-k8s"
  description = "Kubernetes control plane and workers"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-k8s" }
}

resource "aws_vpc_security_group_ingress_rule" "k8s_intra_cluster" {
  security_group_id            = aws_security_group.k8s.id
  description                  = "Node-to-node traffic (API server, kubelet, Flannel VXLAN, pods)"
  referenced_security_group_id = aws_security_group.k8s.id
  ip_protocol                  = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "k8s_ingress_from_alb" {
  security_group_id            = aws_security_group.k8s.id
  description                  = "ingress-nginx NodePort through the ALB"
  referenced_security_group_id = var.alb_sg_id
  from_port                    = var.ingress_node_port
  to_port                      = var.ingress_node_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  for_each = {
    jenkins = aws_security_group.jenkins.id
    k8s     = aws_security_group.k8s.id
  }

  security_group_id = each.value
  description       = "Outbound through the NAT gateway (packages, registries, GitHub)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ------------------------------------------------------------------ Instances
resource "aws_instance" "node" {
  for_each = var.nodes

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = each.value.instance_type
  subnet_id              = var.private_subnet_ids[index(keys(var.nodes), each.key) % length(var.private_subnet_ids)]
  iam_instance_profile   = aws_iam_instance_profile.node.name
  vpc_security_group_ids = [contains(local.k8s_nodes, each.key) ? aws_security_group.k8s.id : aws_security_group.jenkins.id]

  # IMDSv2 only (protects against SSRF credential theft).
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = each.value.disk_size_gb
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "${var.name}-${each.key}"
    Role = each.key
  }

  lifecycle {
    # A newer Ubuntu AMI must not silently replace running nodes.
    ignore_changes = [ami]
  }
}
