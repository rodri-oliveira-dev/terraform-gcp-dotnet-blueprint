output "topic_id" {
  description = "Fully qualified primary Pub/Sub topic ID."
  value       = google_pubsub_topic.primary.id
}

output "topic_name" {
  description = "Primary Pub/Sub topic name."
  value       = google_pubsub_topic.primary.name
}

output "subscription_id" {
  description = "Fully qualified primary Pub/Sub subscription ID."
  value       = google_pubsub_subscription.primary.id
}

output "subscription_name" {
  description = "Primary Pub/Sub subscription name."
  value       = google_pubsub_subscription.primary.name
}

output "dead_letter_topic_id" {
  description = "Dead-letter topic ID when dead lettering is enabled."
  value       = try(google_pubsub_topic.dead_letter[0].id, null)
}

output "dead_letter_topic_name" {
  description = "Dead-letter topic name when dead lettering is enabled."
  value       = try(google_pubsub_topic.dead_letter[0].name, null)
}

output "dead_letter_subscription_name" {
  description = "Inspection subscription attached to the dead-letter topic when enabled."
  value       = try(google_pubsub_subscription.dead_letter[0].name, null)
}

output "pubsub_service_agent_email" {
  description = "Google-managed Pub/Sub service agent used for token minting and dead-letter forwarding."
  value       = local.pubsub_service_agent_email
}

output "push_service_account_email" {
  description = "User-managed service account used as the OIDC identity for push delivery, when configured."
  value       = try(var.push_config.service_account_email, null)
}
