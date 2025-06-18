terraform {
  backend "s3" {
    bucket = "test-terraform"
    region = "us-east-1"
    key = "alpha/test/eks/terraform.tfstate"
  }
}