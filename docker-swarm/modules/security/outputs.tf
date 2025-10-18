output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb_sg.id
}

output "swarm_master_security_group_id" {
  description = "ID of the Swarm Master security group"
  value       = aws_security_group.swarm_master_sg.id
}

output "swarm_worker_security_group_id" {
  description = "ID of the Swarm Worker security group"
  value       = aws_security_group.swarm_worker_sg.id
}