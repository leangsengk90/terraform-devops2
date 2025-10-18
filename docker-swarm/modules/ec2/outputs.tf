output "swarm_master_id" {
  description = "ID of the swarm master instance"
  value       = aws_instance.swarm_master.id
}

output "swarm_master_public_ip" {
  description = "Public IP of the swarm master instance"
  value       = aws_instance.swarm_master.public_ip
}

output "swarm_master_private_ip" {
  description = "Private IP of the swarm master instance"
  value       = aws_instance.swarm_master.private_ip
}

output "autoscaling_group_name" {
  description = "Name of the worker Auto Scaling Group"
  value       = aws_autoscaling_group.swarm_workers.name
}

output "autoscaling_group_arn" {
  description = "ARN of the worker Auto Scaling Group"
  value       = aws_autoscaling_group.swarm_workers.arn
}

# output "private_key" {
#   description = "Private key for SSH access"
#   value       = tls_private_key.swarm_key.private_key_pem
#   sensitive   = true
# }