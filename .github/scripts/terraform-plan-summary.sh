#!/usr/bin/env bash
set -euo pipefail

if (( $# != 2 )); then
  echo "usage: terraform-plan-summary.sh PLAN_FILE SUMMARY_TITLE" >&2
  exit 64
fi

plan_file="$1"
summary_title="$2"

: "${TF_ROOT:?TF_ROOT must identify the selected Terraform root.}"
: "${TARGET_ENVIRONMENT:?TARGET_ENVIRONMENT must identify the selected environment.}"
: "${GITHUB_STEP_SUMMARY:?GITHUB_STEP_SUMMARY must be provided by GitHub Actions.}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT must be provided by GitHub Actions.}"

if [[ ! -f "$plan_file" ]]; then
  echo "::error::Terraform plan file was not created."
  exit 1
fi

safe_summary="$(mktemp)"
trap 'rm -f "$safe_summary"' EXIT

# Hash the complete machine-readable plan without writing the JSON to disk or
# exposing it in logs. The hash lets an apply job prove that its fresh plan is
# byte-for-byte equivalent at the Terraform JSON representation level.
plan_sha256="$(terraform -chdir="$TF_ROOT" show -json "$plan_file" | sha256sum | awk '{print $1}')"

# Persist only non-sensitive review metadata: Terraform addresses and action
# types. Planned/prior attribute values never enter the GitHub Job Summary.
terraform -chdir="$TF_ROOT" show -json "$plan_file" | jq '
  def changed_actions: . != ["no-op"];

  {
    changes: (
      [
        (.resource_changes // [])[]
        | select(.change.actions | changed_actions)
        | {
            address: .address,
            actions: .change.actions
          }
      ]
      +
      [
        (.output_changes // {} | to_entries[]) 
        | select(.value.actions | changed_actions)
        | {
            address: ("output." + .key),
            actions: .value.actions
          }
      ]
      | sort_by(.address)
    )
  }
' > "$safe_summary"

change_count="$(jq -r '.changes | length' "$safe_summary")"
has_destroy="$(jq -r '[.changes[] | select(.actions | index("delete"))] | length > 0' "$safe_summary")"

if (( change_count > 0 )); then
  has_changes=true
else
  has_changes=false
fi

{
  echo "### ${summary_title}"
  echo
  echo "- Environment: \`${TARGET_ENVIRONMENT}\`"
  echo "- Terraform root: \`${TF_ROOT}\`"
  echo "- Commit: \`${GITHUB_SHA:-unknown}\`"
  echo "- Plan fingerprint: \`${plan_sha256}\`"
  echo "- Planned address changes: **${change_count}**"
  echo "- Contains delete/replace actions: **${has_destroy}**"
  echo

  if (( change_count == 0 )); then
    echo "No resource or output changes are planned."
  else
    echo "#### Planned actions"
    echo
    while IFS=$'\t' read -r address actions; do
      printf -- '- `%s`: `%s`\n' "$address" "$actions"
    done < <(
      jq -r '.changes[] | [.address, (.actions | join(" -> "))] | @tsv' "$safe_summary"
    )
  fi

  echo
  echo "> The full binary plan and full plan JSON stay on the ephemeral runner and are not uploaded as artifacts or written to the job summary."
} >> "$GITHUB_STEP_SUMMARY"

{
  echo "plan_sha256=$plan_sha256"
  echo "has_changes=$has_changes"
  echo "has_destroy=$has_destroy"
  echo "change_count=$change_count"
} >> "$GITHUB_OUTPUT"
