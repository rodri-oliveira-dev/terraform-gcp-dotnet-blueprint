output "workload_identity_pool_name" {
  description = "Full resource name of the GitHub Workload Identity Pool."
  value       = google_iam_workload_identity_pool.github.name
}

output "workload_identity_provider_name" {
  description = "Full provider resource name consumed by google-github-actions/auth."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "deployment_service_account_email" {
  description = "Service account email to impersonate from GitHub Actions."
  value       = google_service_account.deployment.email
}

output "github_repository_principal_set" {
  description = "PrincipalSet granted roles/iam.workloadIdentityUser on the deployment service account."
  value       = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository_id/${var.github_repository_id}"
}

output "attribute_condition" {
  description = "Effective GitHub OIDC provider admission condition."
  value       = local.github_attribute_condition
}
