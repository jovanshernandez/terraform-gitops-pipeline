output "instance_ips" {
  description = "Public IP addresses for the EC2 instances."
  value       = aws_instance.default[*].public_ip
}

output "instance_ids" {
  description = "EC2 instance IDs."
  value       = aws_instance.default[*].id
}

output "security_group_id" {
  description = "Security group attached to the EC2 instances."
  value       = aws_security_group.default.id
}
