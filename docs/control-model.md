# Control model

How a Terraform change gets from a branch to AWS in this repo, and which control
stops it at each step. The short version: the pipeline is the only thing that
applies, it applies only from `master`, and it applies only the saved plan that
was reviewed.

## Stages and gates

| Step | Where | Credentials | What stops a bad change |
| --- | --- | --- | --- |
| Static checks | GitHub Actions on every PR, Jenkins on every branch | None | `fmt`, `validate`, `terraform test`, tflint, checkov. A red check blocks merge (with branch protection). |
| Plan | Jenkins, every branch and PR | `terraform-<env>-plan`: read-only AWS role plus read/write on the state key and its `.tflock` object | Plan is saved with `-out`, archived, summarized, and posted to the PR. Reviewers approve the PR against that plan. |
| Merge | GitHub | Repository permissions | Code review. Branch protection on `master` should require the checks above and one approval. |
| Approval | Jenkins `input`, trunk only | `platform-approvers` group | prod always waits for an approver; dev waits only when the plan deletes or replaces a resource. Times out after 30 minutes. |
| Apply | Jenkins, trunk only | `terraform-<env>-apply`, bound only in the Apply stage | Applies the saved plan file from the same build, so what runs is exactly what was approved. |

## Who can apply

- No person runs `terraform apply` against a shared environment. Engineers can
  plan locally with their own read-only credentials.
- The apply credentials are separate Jenkins credentials per environment and are
  only referenced inside the Apply stage, which only runs on `master`.
- For prod, the approver's user ID is recorded in the build log and the build
  refuses to apply prod if no approval was recorded.

## Plan review

- `plan-summary.md` lists counts of create, update, replace and delete, then every
  changed resource, with deletes and replacements first.
- `tfplan.txt` is the full human-readable plan, archived with the build and linked
  from the PR comment.
- The binary `tfplan` is archived too, fingerprinted, so the applied plan can be
  traced back to the build that produced it. Plan files can contain sensitive
  values, so artifact access follows the job's permissions and retention is capped.

## State and locking

- State lives in S3, one key per environment
  (`terraform-gitops-pipeline/<env>/app-host.tfstate`), encrypted at rest.
- Locking uses the S3 backend's native lockfile (`use_lockfile = true`,
  Terraform 1.10+). Terraform writes `<key>.tflock` next to the state with an S3
  conditional write, so there is no DynamoDB table to create, pay for or grant
  access to. HashiCorp has deprecated DynamoDB locking in the S3 backend.
- Migrating an existing stack: set both `use_lockfile = true` and
  `dynamodb_table` for one release so old and new Terraform versions honour the
  same lock, then remove `dynamodb_table` once every runner is on 1.10+.
- On top of the state lock, Jenkins holds a `terraform-<env>` lockable resource
  from plan to apply. That keeps a second build from applying between the moment
  a plan is approved and the moment it runs, which would make the saved plan stale.

## Drift

- A scheduled trunk build runs with `PLAN_ONLY=true` for each environment on
  weekday mornings. It never applies.
- The plan uses `-detailed-exitcode`. Exit code 2 (changes present) on trunk
  means live infrastructure no longer matches `master`; the build is marked
  unstable and the summary shows which resources differ.
- Fixing drift is a normal pull request: either change the code to accept what is
  live, or merge and let the pipeline put it back.

## Environment configuration

- Each environment is a small root in `environments/<env>/` that calls the shared
  `modules/app-host` module. The values that differ (size, count, CIDRs, AMI pin)
  are committed in that root's `main.tf`, so every environment change is a diff in
  a pull request.
- Only the state bucket name is supplied at init time. It is not secret, but it
  is account specific.
- The network is owned by a separate stack and looked up by tag, so this stack
  cannot change VPCs or subnets.
