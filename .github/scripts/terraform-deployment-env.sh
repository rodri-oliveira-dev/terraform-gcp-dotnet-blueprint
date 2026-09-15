#!/usr/bin/env bash
set -euo pipefail

: "${GITHUB_ENV:?GITHUB_ENV must be provided by GitHub Actions.}"
: "${TARGET_ENVIRONMENT:?TARGET_ENVIRONMENT must be dev or prod.}"

missing=0

require_single_line() {
  local name="$1"
  local value="${!name:-}"

  if [[ -z "$value" ]]; then
    echo "::error::Required repository variable ${name} is not configured."
    missing=1
    return
  fi

  if [[ "$value" == *$'\n'* || "$value" == *$'\r'* ]]; then
    echo "::error::Repository variable ${name} must be a single-line value."
    missing=1
  fi
}

for name in \
  GCP_WORKLOAD_IDENTITY_PROVIDER \
  GCP_SERVICE_ACCOUNT \
  GCP_TERRAFORM_STATE_BUCKET; do
  require_single_line "$name"
done

case "$TARGET_ENVIRONMENT" in
  dev)
    TF_ROOT="environments/dev"
    selected_project_variable="GCP_DEV_PROJECT_ID"
    selected_api_image_variable="TF_DEV_API_IMAGE"
    selected_worker_image_variable="TF_DEV_WORKER_IMAGE"
    selected_batch_image_variable="TF_DEV_BATCH_IMAGE"
    selected_workloads_variable="TF_DEV_ENABLE_WORKLOADS"
    ;;
  prod)
    TF_ROOT="environments/prod"
    selected_project_variable="GCP_PROD_PROJECT_ID"
    selected_api_image_variable="TF_PROD_API_IMAGE"
    selected_worker_image_variable="TF_PROD_WORKER_IMAGE"
    selected_batch_image_variable="TF_PROD_BATCH_IMAGE"
    selected_workloads_variable="TF_PROD_ENABLE_WORKLOADS"
    ;;
  *)
    echo "::error::TARGET_ENVIRONMENT must be dev or prod."
    exit 1
    ;;
esac

for name in \
  "$selected_project_variable" \
  "$selected_api_image_variable" \
  "$selected_worker_image_variable" \
  "$selected_batch_image_variable" \
  "$selected_workloads_variable"; do
  require_single_line "$name"
done

if (( missing != 0 )); then
  exit 1
fi

GCP_PROJECT_ID="${!selected_project_variable}"
TF_VAR_api_image="${!selected_api_image_variable}"
TF_VAR_worker_image="${!selected_worker_image_variable}"
TF_VAR_batch_image="${!selected_batch_image_variable}"
TF_VAR_enable_workloads="${!selected_workloads_variable}"

if [[ "$TF_VAR_enable_workloads" != "true" && "$TF_VAR_enable_workloads" != "false" ]]; then
  echo "::error::${selected_workloads_variable} must be exactly true or false."
  exit 1
fi

{
  echo "TF_ROOT=$TF_ROOT"
  echo "GCP_PROJECT_ID=$GCP_PROJECT_ID"
  echo "TF_VAR_project_id=$GCP_PROJECT_ID"
  echo "TF_VAR_api_image=$TF_VAR_api_image"
  echo "TF_VAR_worker_image=$TF_VAR_worker_image"
  echo "TF_VAR_batch_image=$TF_VAR_batch_image"
  echo "TF_VAR_enable_workloads=$TF_VAR_enable_workloads"
} >> "$GITHUB_ENV"

echo "Selected Terraform root ${TF_ROOT} for ${TARGET_ENVIRONMENT}."
