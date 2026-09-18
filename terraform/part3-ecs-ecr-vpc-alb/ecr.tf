resource "aws_ecr_repository" "backend" {
  name                 = "flask-backend-tf"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = {
    Name = "flask-backend-tf"
  }
}

resource "aws_ecr_repository" "frontend" {
  name                 = "express-frontend-tf"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = {
    Name = "express-frontend-tf"
  }
}
