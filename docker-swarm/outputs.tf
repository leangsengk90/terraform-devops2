output "load_balancer_url" {
  description = "URL of the Application Load Balancer"
  value       = module.alb.load_balancer_url
}

output "load_balancer_dns_name" {
  description = "DNS name of the load balancer"
  value       = module.alb.load_balancer_dns_name
}

output "swarm_master_public_ip" {
  description = "Public IP of the Docker Swarm master"
  value       = module.ec2.swarm_master_public_ip
}

output "swarm_master_private_ip" {
  description = "Private IP of the Docker Swarm master"
  value       = module.ec2.swarm_master_private_ip
}

output "ecr_repository_url" {
  description = "URL of the main ECR repository"
  value       = module.ecr.app_repository_url
}

output "autoscaling_group_name" {
  description = "Name of the worker Auto Scaling Group"
  value       = module.ec2.autoscaling_group_name
}

output "key_pair_name" {
  description = "Name of the EC2 key pair"
  value       = "${var.project_name}-swarm-key"
}

# output "private_key" {
#   description = "Private key for SSH access to swarm nodes"
#   value       = module.ec2.private_key
#   sensitive   = true
# }

# Deployment instructions
output "deployment_instructions" {
  description = "Instructions for deploying services to the Docker Swarm"
  value = <<-EOT
    🚀 Docker Swarm Infrastructure Deployed Successfully!
    
    📋 Infrastructure Summary:
    • Load Balancer URL: ${module.alb.load_balancer_url}
    • Swarm Master IP: ${module.ec2.swarm_master_public_ip}
    • ECR Repository: ${module.ecr.app_repository_url}
    
    🔧 Deployment Commands:
    
    1. SSH to the master node:
       ssh -i <your-private-key> ec2-user@${module.ec2.swarm_master_public_ip}
    
    2. Deploy a service (from master node):
       sudo /opt/swarm/deploy-service.sh <service-name> <image-tag> <port> [replicas]
       
       Example:
       sudo /opt/swarm/deploy-service.sh web latest 8080 3
    
    3. Push images to ECR:
       aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${module.ecr.app_repository_url}
       docker tag your-image:latest ${module.ecr.app_repository_url}:latest
       docker push ${module.ecr.app_repository_url}:latest
    
    4. Scale services:
       docker service scale <service-name>=<replica-count>
    
    5. Monitor services:
       docker service ls
       docker service ps <service-name>
    
    📊 Auto Scaling:
    • Min workers: ${var.worker_min_size}
    • Max workers: ${var.worker_max_size}
    • Current desired: ${var.worker_desired_capacity}
    
    🔒 Security:
    • ALB Security Group: Public HTTP/HTTPS access
    • Swarm Security Groups: Restricted to VPC and necessary ports
    • IAM roles: ECR access, CloudWatch logs, Systems Manager
  EOT
}