output "id" {
  description = "Fully qualified Cloud Run job resource ID."
  value       = google_cloud_run_v2_job.this.id
}

output "name" {
  description = "Cloud Run job name."
  value       = google_cloud_run_v2_job.this.name
}

output "location" {
  description = "Google Cloud region containing the Cloud Run job."
  value       = google_cloud_run_v2_job.this.location
}

output "project" {
  description = "Google Cloud project containing the Cloud Run job."
  value       = google_cloud_run_v2_job.this.project
}

output "service_account" {
  description = "Runtime service account configured for Cloud Run job tasks."
  value       = var.service_account
}

output "execution_uri" {
  description = "Cloud Run Admin API URI used to start an execution of this job."
  value       = "https://run.googleapis.com/v2/projects/${var.project_id}/locations/${var.location}/jobs/${google_cloud_run_v2_job.this.name}:run"
}
