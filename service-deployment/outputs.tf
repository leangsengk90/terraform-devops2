output "deployed_services" {
  description = "List of deployed service stack names"
  value       = var.services[*].stack_name
}
