# GitOps Terraform Jenkins

Reference implementation for a pull-request driven Terraform workflow in Jenkins. The repo is intentionally small, but it models the controls I expect in a production infrastructure pipeline:

- Remote S3 state with DynamoDB locking
- Terraform formatting and validation before planning
- Plan artifact archived on every branch
- Manual approval before production apply
- `master` branch apply only
- Parameterized AWS region, AMI, instance count, CIDR ranges, and tags
- EC2 hardening defaults such as IMDSv2 and encrypted root volumes

## Architecture

```text
GitHub pull request
  -> Jenkins checkout
  -> terraform fmt -check
  -> terraform init
  -> terraform validate
  -> terraform plan -out=tfplan
  -> archive tfplan
  -> manual approval on master
  -> terraform apply tfplan
```

The Terraform creates a small EC2 fleet behind a security group. HTTP and SSH CIDR ranges are variables so the same workflow can support demo, lab, or controlled internal environments without editing resource code.

## Repository Layout

```text
.
├── Jenkinsfile      # CI/CD workflow for plan and gated apply
├── main.tf          # Provider, backend, EC2, security group
├── variables.tf     # Typed inputs and validation
└── output.tf        # Instance IDs and public IPs
```

## Jenkins Requirements

- Terraform 1.5 or newer installed on Jenkins agents
- AWS credentials stored in Jenkins as `awsCredentials`
- S3 bucket and DynamoDB lock table for Terraform state
- Jenkins plugins:
  - Pipeline
  - GitHub Branch Source
  - Credentials Binding
  - Workspace Cleanup
  - AnsiColor
  - CloudBees AWS Credentials

## State Backend

The backend is configured in `main.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "baxter-terraform-bucket"
    key            = "gitops-workflow/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

For a real deployment, create the S3 bucket and DynamoDB lock table before the first pipeline run.

## Local Commands

```bash
terraform fmt -recursive
terraform init
terraform validate
terraform plan -out=tfplan
```

## Design Notes

- `master` is the only branch allowed to apply infrastructure changes.
- Non-`master` branches still produce a plan so reviewers can inspect blast radius.
- CIDR inputs default to open demo values, but they are isolated in variables to make tightening access explicit.
- The EC2 metadata endpoint requires tokens to reduce credential exposure from SSRF-style attacks.
