terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Partial backend: the bucket comes from -backend-config at init time
  # (Jenkins passes it; locally use backend.hcl from backend.hcl.example).
  # use_lockfile = true takes the state lock with an S3 conditional write
  # (Terraform 1.10+), so no DynamoDB table is needed.
  backend "s3" {
    key          = "terraform-gitops-pipeline/dev/app-host.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
