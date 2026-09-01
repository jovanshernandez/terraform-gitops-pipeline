# Terraform Review Checklist

Use this checklist before approving a plan or applying changes from the Jenkins pipeline.

## Pipeline Controls

- Confirm the branch is expected to run `apply`. Only the configured trunk branch should reach the gated apply stage.
- Review `tfplan.txt` from the archived Jenkins artifacts instead of approving from memory.
- Confirm the state bucket and lock table are reachable before retrying failed runs.
- Keep failed plans attached to the build so reviewers can compare the next run.

## Infrastructure Review

- Check that security group CIDR changes are intentional and documented.
- Check whether SSH ingress is enabled, and confirm why Session Manager or another private access path is not sufficient.
- Confirm EC2 AMI, instance type, and instance count changes match the environment.
- Verify tags include enough ownership context for cost, incident response, and cleanup.
- Treat replacement or destroy actions as high-risk until the owner confirms them.

## Operational Readiness

- Confirm rollback is clear before approving production apply.
- Prefer small, reviewable changes over broad infrastructure updates.
- Record any manual approval context in the Jenkins build before applying.
- After apply, verify outputs and AWS resource health before closing the change.
