output "alert_policy_ids" {
  description = "Cloud Monitoring alert policies created by the example."
  value       = module.alerts.alert_policy_ids
}
