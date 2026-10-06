# Terraform review checklist

Use this before approving a pull request or the Jenkins `input` step.

## Pipeline

- The PR's static checks are green: fmt, validate, `terraform test`, tflint, checkov.
- The plan comment on the PR comes from the latest commit on the branch.
- Only `master` reaches Approve and Apply. A branch build that tries to apply is a bug.
- Approve from `plan-summary.md` and `tfplan.txt` in the build artifacts, not from memory.
- If the build waited on the `terraform-<env>` lock or the state lock, re-read the
  plan: something else may have changed the environment first.

## Infrastructure

- Every `replace` and `delete` in the summary is expected and explained in the PR.
- Ingress changes stay inside private ranges and the app port. Port 22 never opens;
  shell access is through Session Manager.
- AMI pin bumps replace instances. In prod, confirm instances are spread across
  subnets so a rolling replacement keeps capacity.
- Instance type, count and volume changes match the environment's purpose.
- Tags still identify the owner and service for cost and incident response.

## After apply

- Outputs look right (`instance_ids`, `private_ips`).
- Instances show as managed in Systems Manager and the service passes its health check.
- The next scheduled drift check for the environment is clean.
