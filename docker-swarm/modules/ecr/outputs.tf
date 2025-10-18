output "app_repository_url" {
  description = "URL of the main application ECR repository"
  value       = aws_ecr_repository.app_repo.repository_url
}

output "app_repository_arn" {
  description = "ARN of the main application ECR repository"
  value       = aws_ecr_repository.app_repo.arn
}