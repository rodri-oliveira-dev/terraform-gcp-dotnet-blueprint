output "api_runtime_service_account" {
  description = "Service account email to pass to modules/cloud-run-service.service_account."
  value       = module.api_identity.email
}

output "api_secret_environment_variables" {
  description = "Secret references to pass directly to modules/cloud-run-service.secret_environment_variables."
  value       = local.api_secret_environment_variables
}

output "worker_runtime_service_account" {
  description = "Service account email to pass to a worker Cloud Run service or job runtime."
  value       = module.worker_identity.email
}

output "worker_secret_environment_variables" {
  description = "Secret references to pass directly to a worker Cloud Run service/job secret_environment_variables input."
  value       = local.worker_secret_environment_variables
}
