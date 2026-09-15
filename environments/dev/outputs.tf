output "environment" {
  description = "Environment name represented by this root module."
  value       = local.environment
}

output "workloads_enabled" {
  description = "Whether Cloud Run workloads, Pub/Sub delivery, and the scheduler are enabled."
  value       = var.enable_workloads
}

output "network" {
  description = "Development VPC and subnet identifiers used by Direct VPC egress."
  value = {
    network_id = module.network.network_id
    subnet_id  = module.network.subnet_id
  }
}

output "cache_connection" {
  description = "Non-secret Redis connection metadata. AUTH strings and CA payloads are intentionally excluded."
  value       = module.cache.connection
}

output "runtime_service_accounts" {
  description = "Workload-specific runtime service account emails."
  value = {
    api    = module.api_identity.email
    worker = module.worker_identity.email
    batch  = module.batch_identity.email
  }
}

output "transport_service_accounts" {
  description = "Transport/trigger service account emails kept separate from workload runtime identities."
  value = {
    pubsub_push = google_service_account.pubsub_push.email
    scheduler   = google_service_account.scheduler.email
  }
}

output "secret_bootstrap" {
  description = "Secret IDs that must receive versions from a trusted process before enable_workloads is switched to true."
  value = {
    api_config    = module.api_config_secret.secret_id
    worker_config = module.worker_config_secret.secret_id
    batch_config  = module.batch_config_secret.secret_id
    redis_auth    = module.redis_auth_secret.secret_id
    redis_ca      = module.redis_ca_secret.secret_id
  }
}

output "api_uri" {
  description = "Development API URI when workloads are enabled. Invocation is not made public by this root."
  value       = var.enable_workloads ? module.api[0].uri : null
}

output "worker_uri" {
  description = "Development Pub/Sub worker URI when workloads are enabled."
  value       = var.enable_workloads ? module.worker[0].uri : null
}

output "events_topic" {
  description = "Primary Pub/Sub topic name when workloads are enabled."
  value       = var.enable_workloads ? module.events[0].topic_name : null
}

output "dead_letter_topic" {
  description = "Pub/Sub dead-letter topic name when workloads are enabled."
  value       = var.enable_workloads ? module.events[0].dead_letter_topic_name : null
}

output "batch_execution_uri" {
  description = "Cloud Run Admin API execution URI for the development batch job when enabled."
  value       = var.enable_workloads ? module.batch[0].execution_uri : null
}

output "batch_scheduler_name" {
  description = "Cloud Scheduler job name when workloads are enabled."
  value       = var.enable_workloads ? google_cloud_scheduler_job.batch[0].name : null
}
