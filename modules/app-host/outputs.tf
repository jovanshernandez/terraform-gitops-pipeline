output "instance_ids" {
  description = "EC2 instance IDs, in creation order."
  value       = aws_instance.this[*].id
}

output "private_ips" {
  description = "Private IP addresses of the instances."
  value       = aws_instance.this[*].private_ip
}

output "security_group_id" {
  description = "Security group attached to every instance."
  value       = aws_security_group.this.id
}

output "instance_role_name" {
  description = "IAM role assumed by the instances."
  value       = aws_iam_role.this.name
}

output "ssm_session_commands" {
  description = "Commands to open a shell on each instance through Session Manager."
  value       = [for id in aws_instance.this[*].id : "aws ssm start-session --target ${id}"]
}

output "instance_subnet_ids" {
  description = "Subnet of each instance, in creation order. Known at plan time."
  value       = aws_instance.this[*].subnet_id
}
