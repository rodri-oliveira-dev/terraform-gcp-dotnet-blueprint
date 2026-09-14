output "id" {
  description = "Fully qualified Cloud Run service resource ID."
  value       = google_cloud_run_v2_service.this.id
}

output "name" {
  description = "Cloud Run service name."
  value       = google_cloud_run_v2_service.this.name
}

output "uri" {
  description = "Serving URI assigned to the Cloud Run service."
  value       = google_cloud_run_v2_service.this.uri
}

output "location" {
  description = "Google Cloud region containing the Cloud Run service."
  value       = google_cloud_run_v2_service.this.location
}

output "project" {
  description = "Google Cloud project containing the Cloud Run service."
  value       = google_cloud_run_v2_service.this.project
}

output "service_account" {
  description = "Runtime service account configured for Cloud Run revisions."
  value       = var.service_account
}
