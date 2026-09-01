# GitOps Terraform Jenkins

Reference implementation for a pull-request driven Terraform workflow in Jenkins. The repo is intentionally small, but it models the controls I expect in a production infrastructure pipeline:

- Remote S3 state with DynamoDB locking through environment-specific backend files
- Terraform formatting and validation before planning
- Plan artifact archived on every branch
- Manual approval before production apply
- Protected trunk-branch apply only
- Parameterized AWS region, AMI, instance count, CIDR ranges, SSH ingress, and tags
- EC2 hardening defaults such as IMDSv2 and encrypted root volumes
- GitHub static checks for formatting and backend-free validation before Jenkins apply

## Architecture

```text
GitHub pull request
  -> Jenkins checkout
  -> terraform fmt -check
  -> terraform init with backend config
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
├── docs/            # Reviewer and operational guidance
├── backend/         # Backend examples for state and locking
├── env/             # Environment variable examples
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

The backend block is intentionally empty in `main.tf`; each environment supplies its own backend configuration:

```bash
cp backend/dev.hcl.example backend/dev.hcl
terraform init -backend-config=backend/dev.hcl
```

For a real deployment, create the S3 bucket and DynamoDB lock table before the first pipeline run.

## Local Commands

```bash
terraform fmt -recursive
terraform init -backend-config=backend/dev.hcl
terraform validate
terraform plan -var-file=env/dev.tfvars -out=tfplan
```

## Review Workflow

See [docs/review-checklist.md](docs/review-checklist.md) and [docs/control-model.md](docs/control-model.md) for the checks I would expect before approving a plan. The goal is to make the project demonstrate operational judgment: reviewers should inspect blast radius, access changes, replacement actions, and rollback expectations before applying infrastructure.

## Design Notes

- The configured trunk branch is the only branch allowed to apply infrastructure changes.
- Non-trunk branches still produce a plan so reviewers can inspect blast radius.
- CIDR inputs default to private ranges, and SSH ingress is disabled unless an environment explicitly enables it.
- The EC2 metadata endpoint requires tokens to reduce credential exposure from SSRF-style attacks.

## Resume Positioning

This project is strongest on a Platform Engineer resume as an example of infrastructure delivery controls: typed Terraform inputs, remote state and locking, pull-request plans, archived artifacts, branch-gated applies, and manual approval. It is also useful for SRE roles because it shows change management discipline and an awareness of blast radius before production changes.
