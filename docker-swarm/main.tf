# Data source to get VPC information
data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["docker-swarm-vpc"]
  }
}

# Data source to get subnet information
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }

  tags = {
    Name = "public-subnet-*"
  }
}

# Data source to get private subnets for worker nodes
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }

  tags = {
    Name = "private-subnet-*"
  }
}

# Local values
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  # Simplified service configuration for basic load balancing
  service_configs = [
    {
      name                 = "app"
      port                 = 8080
      path_patterns        = ["/*"]
      health_check_path    = "/health"
      health_check_matcher = "200"
      host_headers         = null
    }
  ]
}

# IAM Module
module "iam" {
  source = "./modules/iam"

  project_name = var.project_name
  tags         = local.common_tags
}

# Security Groups Module
module "security" {
  source = "./modules/security"

  project_name       = var.project_name
  vpc_id             = data.aws_vpc.main.id
  allowed_ssh_cidrs  = var.allowed_ssh_cidrs
  tags               = local.common_tags
}

# ECR Module
module "ecr" {
  source = "./modules/ecr"

  project_name      = var.project_name
  tags              = local.common_tags
}

# ALB Module
module "alb" {
  source = "./modules/alb"

  project_name           = var.project_name
  vpc_id                 = data.aws_vpc.main.id
  public_subnet_ids      = data.aws_subnets.public.ids
  alb_security_group_id  = module.security.alb_security_group_id
  ssl_certificate_arn    = var.ssl_certificate_arn
  service_configs        = local.service_configs
  tags                   = local.common_tags
}

# EC2 Module (Docker Swarm Cluster)
module "ec2" {
  source = "./modules/ec2"

  project_name                 = var.project_name
  public_key                   = var.public_key
  aws_region                   = var.aws_region
  ecr_repository_url           = module.ecr.app_repository_url
  master_instance_type         = var.master_instance_type
  worker_instance_type         = var.worker_instance_type
  master_security_group_id     = module.security.swarm_master_security_group_id
  worker_security_group_id     = module.security.swarm_worker_security_group_id
  iam_instance_profile_name    = module.iam.ec2_instance_profile_name
  public_subnet_ids            = data.aws_subnets.public.ids
  private_subnet_ids           = data.aws_subnets.private.ids
  target_group_arns            = module.alb.target_group_arns
  worker_min_size              = var.worker_min_size
  worker_max_size              = var.worker_max_size
  worker_desired_capacity      = var.worker_desired_capacity
  tags                         = local.common_tags

  depends_on = [module.alb]
}

# Systems Manager Parameters for Swarm Token and Master IP (for secure sharing)
resource "aws_ssm_parameter" "swarm_worker_token" {
  name        = "/docker-swarm/worker-token"
  description = "Docker Swarm worker join token"
  type        = "SecureString"
  value       = "placeholder" # This will be updated by the master instance

  tags = local.common_tags

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "swarm_master_ip" {
  name        = "/docker-swarm/master-ip"
  description = "Docker Swarm master IP address"
  type        = "String"
  value       = "placeholder" # This will be updated by the master instance

  tags = local.common_tags

  lifecycle {
    ignore_changes = [value]
  }
}