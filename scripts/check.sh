#!/usr/bin/env bash
# Offline checks for every Terraform root: fmt, validate and terraform test.
# Needs no AWS credentials and no backend; the AWS provider is mocked in tests.
#
#   scripts/check.sh
set -euo pipefail

cd "$(dirname "$0")/.."

roots=(modules/app-host environments/dev environments/prod)

echo "==> terraform fmt -check -recursive"
terraform fmt -check -recursive -diff
echo "all files formatted"

for dir in "${roots[@]}"; do
  echo
  echo "==> ${dir}"
  terraform -chdir="$dir" init -backend=false -input=false > /dev/null
  terraform -chdir="$dir" validate
  terraform -chdir="$dir" test
done
