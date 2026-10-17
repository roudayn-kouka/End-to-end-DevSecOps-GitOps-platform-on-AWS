output "instance_ids" {
  value = { for role, instance in aws_instance.node : role => instance.id }
}

output "private_ips" {
  value = { for role, instance in aws_instance.node : role => instance.private_ip }
}

output "ssm_bucket" {
  value = aws_s3_bucket.ssm.bucket
}
