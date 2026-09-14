output "cloud_run_job_name" {
  description = "Cloud Run job started by the schedule."
  value       = module.batch.name
}

output "cloud_run_job_execution_uri" {
  description = "Cloud Run Admin API URI targeted by Cloud Scheduler."
  value       = module.batch.execution_uri
}

output "scheduler_job_name" {
  description = "Cloud Scheduler job responsible for starting the batch job."
  value       = google_cloud_scheduler_job.batch.name
}

output "scheduler_service_account" {
  description = "Identity granted invocation permission on the Cloud Run job."
  value       = var.scheduler_service_account
}
