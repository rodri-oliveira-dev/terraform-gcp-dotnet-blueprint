output "worker_uri" {
  description = "Cloud Run URI receiving authenticated Pub/Sub push requests."
  value       = module.worker.uri
}

output "topic_name" {
  description = "Primary Pub/Sub topic name."
  value       = module.events.topic_name
}

output "subscription_name" {
  description = "Primary Pub/Sub push subscription name."
  value       = module.events.subscription_name
}

output "dead_letter_topic_name" {
  description = "Dead-letter topic name."
  value       = module.events.dead_letter_topic_name
}

output "dead_letter_subscription_name" {
  description = "Dead-letter inspection subscription name."
  value       = module.events.dead_letter_subscription_name
}
