terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}

# Security group for the Flask backend instance
resource "aws_security_group" "backend_sg" {
  name        = "separate-ec2-backend-sg"
  description = "Allow SSH and Flask traffic"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Flask backend"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "separate-ec2-backend-sg"
  }
}

# Security group for the Express frontend instance
resource "aws_security_group" "frontend_sg" {
  name        = "separate-ec2-frontend-sg"
  description = "Allow SSH and Express traffic"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Express frontend"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "separate-ec2-frontend-sg"
  }
}

# Backend instance — created first, since frontend needs its IP
resource "aws_instance" "backend" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  user_data              = file("${path.module}/user-data-backend.sh")

  tags = {
    Name = "flask-backend-instance"
  }
}

# Frontend instance — its user-data is rendered with the backend's public IP
resource "aws_instance" "frontend" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.frontend_sg.id]

  user_data = templatefile("${path.module}/user-data-frontend.sh.tpl", {
    backend_ip = aws_instance.backend.public_ip
  })

  tags = {
    Name = "express-frontend-instance"
  }

  # Ensure backend is created (and has a public IP) before frontend starts
  depends_on = [aws_instance.backend]
}
