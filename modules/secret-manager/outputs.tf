output "secret_id" {
  description = "Secret ID suitable for Cloud Run Secret Manager references."
  value       = google_secret_manager_secret.this.secret_id
}

output "name" {
  description = "Fully qualified Secret Manager secret resource name."
  value       = google_secret_manager_secret.this.name
}

output "secret_reference" {
  description = "Typed reference compatible with Cloud Run service/job secret_environment_variables values. No secret payload is exposed."
  value = {
    secret  = google_secret_manager_secret.this.secret_id
    version = var.reference_version
  }
}

output "accessor_service_account_emails" {
  description = "Service account emails granted Secret Manager Secret Accessor on this secret."
  value       = var.accessor_service_account_emails
}
