output "alert_policy_ids" {
  description = "Alert policy IDs grouped by monitored capability. Null values indicate optional targets that were not configured."
  value = {
    cloud_run_server_errors = {
      for key, policy in google_monitoring_alert_policy.cloud_run_server_errors : key => policy.id
    }
    cloud_run_job_failure         = try(google_monitoring_alert_policy.cloud_run_job_failure[0].id, null)
    pubsub_backlog_age            = try(google_monitoring_alert_policy.pubsub_backlog_age[0].id, null)
    pubsub_dead_letter_forwarding = try(google_monitoring_alert_policy.pubsub_dead_letter_forwarding[0].id, null)
    redis_memory_pressure         = try(google_monitoring_alert_policy.redis_memory_pressure[0].id, null)
    redis_rejected_connections    = try(google_monitoring_alert_policy.redis_rejected_connections[0].id, null)
  }
}

output "notification_channels" {
  description = "Existing notification channel resource names attached to every policy managed by this module."
  value       = local.notification_channels
}
