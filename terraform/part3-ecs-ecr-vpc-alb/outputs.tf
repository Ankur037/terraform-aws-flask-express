output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "ecr_backend_repository_url" {
  value = aws_ecr_repository.backend.repository_url
}

output "ecr_frontend_repository_url" {
  value = aws_ecr_repository.frontend.repository_url
}

output "alb_dns_name" {
  description = "Public DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "frontend_url" {
  description = "URL to access the Express frontend via ALB"
  value       = "http://${aws_lb.main.dns_name}:3000"
}

output "backend_url" {
  description = "URL to access the Flask backend via ALB"
  value       = "http://${aws_lb.main.dns_name}:5000"
}
