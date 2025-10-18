variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "docker-swarm"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "public_key" {
  description = "Public key for EC2 key pair"
  type        = string
  default     = "~/.ssh/docker-swarm-key.pub"
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["10.0.0.0/16"]
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

variable "ssl_certificate_arn" {
  description = "ARN of SSL certificate for HTTPS listener"
  type        = string
  default     = null
}