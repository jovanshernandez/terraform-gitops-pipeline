output "instance_ids" {
  description = "EC2 instance IDs."
  value       = module.app.instance_ids
}

output "instance_subnet_ids" {
  description = "Subnet of each instance."
  value       = module.app.instance_subnet_ids
}

output "private_ips" {
  description = "Private IP addresses of the instances."
  value       = module.app.private_ips
}

output "security_group_id" {
  description = "Security group attached to the instances."
  value       = module.app.security_group_id
}

output "ssm_session_commands" {
  description = "Session Manager commands to reach each instance."
  value       = module.app.ssm_session_commands
}
