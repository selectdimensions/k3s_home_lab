terraform {
  backend "s3" {
    bucket         = "pi-cluster-terraform-state"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "pi-cluster-terraform-locks"

    # Enable versioning for state file history
    versioning = true
  }
}