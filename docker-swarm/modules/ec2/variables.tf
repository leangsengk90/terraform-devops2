variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "public_key" {
  description = "Public key for EC2 key pair"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "ecr_repository_url" {
  description = "ECR repository URL for Docker images"
  type        = string
}

variable "master_instance_type" {
  description = "Instance type for swarm master"
  type        = string
  default     = "t2.micro"
}

variable "worker_instance_type" {
  description = "Instance type for swarm workers"
  type        = string
  default     = "t2.micro"
}

variable "master_security_group_id" {
  description = "Security group ID for swarm master"
  type        = string
}

variable "worker_security_group_id" {
  description = "Security group ID for swarm workers"
  type        = string
}

variable "iam_instance_profile_name" {
  description = "IAM instance profile name for EC2 instances"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for worker nodes"
  type        = list(string)
}

variable "target_group_arns" {
  description = "List of target group ARNs for Auto Scaling Group"
  type        = list(string)
  default     = []
}

variable "worker_min_size" {
  description = "Minimum number of worker instances"
  type        = number
  default     = 2
}

variable "worker_max_size" {
  description = "Maximum number of worker instances"
  type        = number
  default     = 6
}

variable "worker_desired_capacity" {
  description = "Desired number of worker instances"
  type        = number
  default     = 2
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}