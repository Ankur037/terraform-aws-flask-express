terraform {
  backend "s3" {
    bucket = "ankur-terraform-state-flask-express"
    key    = "part3/terraform.tfstate"
    region = "ap-south-1"
  }
}
