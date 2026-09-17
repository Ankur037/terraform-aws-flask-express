output "backend_public_ip" {
  description = "Public IP of the Flask backend instance"
  value       = aws_instance.backend.public_ip
}

output "frontend_public_ip" {
  description = "Public IP of the Express frontend instance"
  value       = aws_instance.frontend.public_ip
}

output "frontend_url" {
  description = "URL to access the Express frontend"
  value       = "http://${aws_instance.frontend.public_ip}:3000"
}

output "backend_url" {
  description = "URL to access the Flask backend"
  value       = "http://${aws_instance.backend.public_ip}:5000"
}
