variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where ALB will be created"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ALB"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID for ALB"
  type        = string
}

variable "ssl_certificate_arn" {
  description = "ARN of SSL certificate for HTTPS listener"
  type        = string
  default     = null
}

variable "service_configs" {
  description = "List of service configurations for ALB target groups"
  type = list(object({
    name                   = string
    port                   = number
    path_patterns          = list(string)
    health_check_path      = string
    health_check_matcher   = string
    host_headers          = optional(list(string))
  }))
  default = [
    {
      name                 = "app1"
      port                 = 8080
      path_patterns        = ["/*"]
      health_check_path    = "/"
      health_check_matcher = "200"
      host_headers         = null
    }
  ]
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}