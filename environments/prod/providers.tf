provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "terraform-gitops-pipeline"
      Environment = "prod"
      ManagedBy   = "terraform"
      Repository  = "github.com/jovanshernandez/terraform-gitops-pipeline"
    }
  }
}
