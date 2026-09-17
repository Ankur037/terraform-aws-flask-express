output "instance_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.app_server.public_ip
}

output "frontend_url" {
  description = "URL to access the Express frontend"
  value       = "http://${aws_instance.app_server.public_ip}:3000"
}

output "backend_url" {
  description = "URL to access the Flask backend"
  value       = "http://${aws_instance.app_server.public_ip}:5000"
}
