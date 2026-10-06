#!/usr/bin/env bash
# Summarize a saved Terraform plan for reviewers.
#
#   terraform show -json tfplan > tfplan.json
#   scripts/plan-summary.sh tfplan.json dev > plan-summary.md
#
# Prints Markdown: action counts, then every changed resource grouped by action,
# with deletes and replacements first because they carry the most risk.
set -euo pipefail

plan_json="${1:?usage: plan-summary.sh <plan.json> [environment]}"
environment="${2:-unknown}"

jq -r --arg env "$environment" '
  def action:
    .change.actions as $a
    | if $a == ["create"] then "create"
      elif $a == ["update"] then "update"
      elif $a == ["delete"] then "delete"
      elif ($a | index("delete")) and ($a | index("create")) then "replace"
      else "no-op" end;

  [.resource_changes[]? | select(.mode == "managed") | {address, action: action}]
  | map(select(.action != "no-op")) as $changes
  | ($changes | map(select(.action == "create"))  | length) as $add
  | ($changes | map(select(.action == "update"))  | length) as $change
  | ($changes | map(select(.action == "replace")) | length) as $replace
  | ($changes | map(select(.action == "delete"))  | length) as $destroy
  | "### Terraform plan: \($env)",
    "",
    "| create | update | replace | delete |",
    "| ---: | ---: | ---: | ---: |",
    "| \($add) | \($change) | \($replace) | \($destroy) |",
    "",
    (if ($replace + $destroy) > 0
     then "**Destructive changes present.** Confirm each replace or delete below before approving."
     else "No resources are deleted or replaced." end),
    "",
    (if ($changes | length) == 0 then "No changes. Infrastructure matches the configuration."
     else ($changes
           | sort_by({"delete": 0, "replace": 1, "update": 2, "create": 3}[.action], .address)
           | .[] | "- `\(.action)` \(.address)")
     end)
' "$plan_json"
