variable "services" {
  description = "List of services to deploy, each with compose file and stack name"
  type = list(object({
    compose_file = string
    stack_name   = string
  }))
  default = [
    {
      compose_file = "docker-compose.yml"
      stack_name   = "nginx-stack"
    }
  ]
}

variable "ssh_key_path" {
  description = "Path to the private SSH key for Swarm master access"
  type        = string
  default     = "~/.ssh/docker-swarm-key"
}
