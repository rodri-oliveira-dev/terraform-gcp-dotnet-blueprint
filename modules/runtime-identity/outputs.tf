output "email" {
  description = "Runtime service account email, suitable for Cloud Run service_account inputs."
  value       = google_service_account.this.email
}

output "name" {
  description = "Fully qualified service account resource name."
  value       = google_service_account.this.name
}

output "member" {
  description = "IAM member string for resource-scoped bindings."
  value       = "serviceAccount:${google_service_account.this.email}"
}

output "unique_id" {
  description = "Stable Google-assigned unique ID for the service account."
  value       = google_service_account.this.unique_id
}
