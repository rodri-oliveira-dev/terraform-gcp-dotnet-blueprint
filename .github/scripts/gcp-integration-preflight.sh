#!/usr/bin/env bash
set -euo pipefail

required_services=(
  "cloudresourcemanager.googleapis.com"
  "cloudscheduler.googleapis.com"
  "compute.googleapis.com"
  "iam.googleapis.com"
  "iamcredentials.googleapis.com"
  "monitoring.googleapis.com"
  "pubsub.googleapis.com"
  "redis.googleapis.com"
  "run.googleapis.com"
  "secretmanager.googleapis.com"
  "servicenetworking.googleapis.com"
)

if [[ "${1:-}" == "--print-required-services" ]]; then
  printf '%s\n' "${required_services[@]}"
  exit 0
fi

: "${GCP_PROJECT_ID:?GCP_PROJECT_ID must identify the development validation project.}"
: "${GITHUB_STEP_SUMMARY:?GITHUB_STEP_SUMMARY must be provided by GitHub Actions.}"

command -v gcloud >/dev/null 2>&1 || {
  echo "::error::gcloud is required for the GCP integration preflight."
  exit 1
}

available_file="$(mktemp)"
enabled_file="$(mktemp)"
trap 'rm -f "$available_file" "$enabled_file"' EXIT

# Force an OIDC -> WIF -> service-account token exchange without exposing the
# short-lived token in logs.
gcloud auth print-access-token >/dev/null

resolved_project="$(
  gcloud projects describe "$GCP_PROJECT_ID" \
    --format='value(projectId)' \
    --quiet
)"

if [[ "$resolved_project" != "$GCP_PROJECT_ID" ]]; then
  echo "::error::Authenticated project lookup returned ${resolved_project:-<none>} instead of ${GCP_PROJECT_ID}."
  exit 1
fi

# Service Usage is queried read-only. Availability proves that the APIs used by
# the blueprint exist for this project; enablement is reported separately
# because Terraform intentionally manages google_project_service resources.
gcloud services list \
  --available \
  --project="$GCP_PROJECT_ID" \
  --format='value(name)' \
  --quiet \
  | sort -u > "$available_file"

gcloud services list \
  --enabled \
  --project="$GCP_PROJECT_ID" \
  --format='value(name)' \
  --quiet \
  | sort -u > "$enabled_file"

missing=0

{
  echo "### Real GCP API preflight"
  echo
  echo "- Project: \`${GCP_PROJECT_ID}\`"
  echo "- Authentication: **WIF token exchange succeeded**"
  echo "- Project lookup: **succeeded**"
  echo
  echo "| Required service | Available | Currently enabled |"
  echo "| --- | --- | --- |"

  for service in "${required_services[@]}"; do
    available=false
    enabled=false

    if grep -Fxq "$service" "$available_file"; then
      available=true
    else
      missing=1
    fi

    if grep -Fxq "$service" "$enabled_file"; then
      enabled=true
    fi

    printf '| `%s` | %s | %s |\n' "$service" "$available" "$enabled"
  done

  echo
  echo "> A disabled service is not a preflight failure: the development root owns its enablement through google_project_service. A service missing from the project catalog is a failure."
} >> "$GITHUB_STEP_SUMMARY"

if (( missing != 0 )); then
  echo "::error::One or more APIs required by environments/dev are not available in the selected GCP project."
  exit 1
fi
