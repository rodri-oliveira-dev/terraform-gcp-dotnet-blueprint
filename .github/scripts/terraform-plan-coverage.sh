#!/usr/bin/env bash
set -euo pipefail

expected_resource_types=(
  "google_cloud_run_v2_job"
  "google_cloud_run_v2_service"
  "google_cloud_scheduler_job"
  "google_compute_global_address"
  "google_compute_network"
  "google_compute_subnetwork"
  "google_monitoring_alert_policy"
  "google_pubsub_subscription"
  "google_pubsub_topic"
  "google_redis_instance"
  "google_secret_manager_secret"
  "google_service_networking_connection"
)

if [[ "${1:-}" == "--print-expected-types" ]]; then
  printf '%s\n' "${expected_resource_types[@]}"
  exit 0
fi

if (( $# != 1 )); then
  echo "usage: terraform-plan-coverage.sh PLAN_FILE" >&2
  exit 64
fi

plan_file="$1"

: "${TF_ROOT:?TF_ROOT must identify environments/dev.}"
: "${GITHUB_STEP_SUMMARY:?GITHUB_STEP_SUMMARY must be provided by GitHub Actions.}"

if [[ "$TF_ROOT" != "environments/dev" ]]; then
  echo "::error::Integration plan coverage is intentionally restricted to environments/dev."
  exit 1
fi

if [[ ! -f "$plan_file" ]]; then
  echo "::error::Terraform plan file was not created."
  exit 1
fi

actual_types="$(mktemp)"
trap 'rm -f "$actual_types"' EXIT

# Inspect only Terraform resource type names. Planned/prior attribute values are
# never written to the summary or to a repository artifact.
terraform -chdir="$TF_ROOT" show -json "$plan_file" \
  | jq -r '.resource_changes[]?.type' \
  | sort -u > "$actual_types"

missing=0

{
  echo "### Blueprint contract coverage"
  echo
  echo "The non-applying integration plan materializes the full development graph and must contain the resource types that represent each major runtime capability."
  echo
  echo "| Capability contract | Terraform resource type | Present in plan |"
  echo "| --- | --- | --- |"

  while IFS='|' read -r capability resource_type; do
    present=false
    if grep -Fxq "$resource_type" "$actual_types"; then
      present=true
    else
      missing=1
    fi

    printf '| %s | `%s` | %s |\n' "$capability" "$resource_type" "$present"
  done <<'EOF'
Cloud Run service|google_cloud_run_v2_service
Cloud Run job|google_cloud_run_v2_job
Cloud Scheduler|google_cloud_scheduler_job
VPC network|google_compute_network
VPC subnet|google_compute_subnetwork
Private Service Access range|google_compute_global_address
Private Service Access connection|google_service_networking_connection
Pub/Sub topic|google_pubsub_topic
Pub/Sub subscription|google_pubsub_subscription
Secret Manager|google_secret_manager_secret
Memorystore for Redis|google_redis_instance
Cloud Monitoring|google_monitoring_alert_policy
EOF

  echo
  echo "> This check proves provider-plan coverage of the configured resource contracts. It does not prove successful create/update calls; those require an explicitly authorized apply and remain outside issue #29."
} >> "$GITHUB_STEP_SUMMARY"

if (( missing != 0 )); then
  echo "::error::The development integration plan did not materialize every expected blueprint resource contract."
  exit 1
fi
