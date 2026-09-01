# Control Model

This repo models the change controls expected around infrastructure delivery rather than trying to be a large Terraform estate.

## What Gets Checked

- Terraform formatting is required before planning.
- Terraform validation runs without backend access in GitHub Actions.
- Jenkins performs the full backend-backed init, plan, artifact archive, approval, and apply path.
- Production apply is branch-gated and requires manual approval.

## What Reviewers Should Inspect

- Resource replacement and destroy actions.
- Security group ingress changes.
- Backend configuration and state-locking behavior.
- Environment-specific variable files.
- Tags used for ownership, cost, and incident response.

## Why It Matters

Platform engineering is not only writing Terraform. The platform has to make the safe path easy: reviewers need a plan artifact, state needs locking, production changes need an approval point, and defaults should avoid implying broad network exposure.
