terraform {
  required_version = ">= 1.5.0"
  backend "s3" {
    bucket  = "rajesh-grievanceapp-tfstate"   
    key     = "rajeshnew/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
    # dynamodb_table = "rajesh-grievanceapp-tf-lock"   
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}