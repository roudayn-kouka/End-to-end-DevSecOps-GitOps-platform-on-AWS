output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "nat_public_ip" {
  description = "Egress IP of every node (useful for allow-lists)"
  value       = aws_eip.nat.public_ip
}
