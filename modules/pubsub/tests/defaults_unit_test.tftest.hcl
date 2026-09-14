mock_provider "google" {
  mock_data "google_project" {
    defaults = {
      number = "123456789012"
    }
  }
}

variables {
  project_id        = "example-project"
  topic_name        = "orders-events"
  subscription_name = "orders-worker"

  push_config = {
    endpoint              = "https://orders-worker-abc.run.app/"
    service_account_email = "orders-push@example-project.iam.gserviceaccount.com"
    audience              = "https://orders-worker-abc.run.app"
  }
}

run "plan_secure_push_worker_defaults" {
  command = plan

  assert {
    condition     = google_pubsub_topic.primary.name == "orders-events"
    error_message = "The primary topic name was not mapped correctly."
  }

  assert {
    condition     = google_pubsub_subscription.primary.ack_deadline_seconds == 60
    error_message = "The default acknowledgement deadline must be 60 seconds."
  }

  assert {
    condition     = google_pubsub_subscription.primary.message_retention_duration == "604800s"
    error_message = "The default subscription retention must be seven days."
  }

  assert {
    condition     = google_pubsub_subscription.primary.retry_policy[0].minimum_backoff == "10s" && google_pubsub_subscription.primary.retry_policy[0].maximum_backoff == "600s"
    error_message = "The default retry policy was not mapped correctly."
  }

  assert {
    condition     = google_pubsub_subscription.primary.dead_letter_policy[0].max_delivery_attempts == 10
    error_message = "Dead-letter forwarding must default to ten delivery attempts."
  }

  assert {
    condition     = google_pubsub_subscription.primary.push_config[0].push_endpoint == "https://orders-worker-abc.run.app/"
    error_message = "Push delivery must target the configured request-serving endpoint."
  }

  assert {
    condition     = google_pubsub_subscription.primary.push_config[0].oidc_token[0].service_account_email == "orders-push@example-project.iam.gserviceaccount.com"
    error_message = "Authenticated push delivery must use the configured service account."
  }

  assert {
    condition     = google_service_account_iam_member.push_token_creator[0].role == "roles/iam.serviceAccountTokenCreator"
    error_message = "The Pub/Sub service agent must be able to mint OIDC tokens for authenticated push delivery."
  }

  assert {
    condition     = google_pubsub_topic_iam_member.dead_letter_publisher[0].role == "roles/pubsub.publisher"
    error_message = "Dead-letter forwarding must grant the Pub/Sub service agent publisher access only on the DLQ topic."
  }

  assert {
    condition     = google_pubsub_subscription_iam_member.dead_letter_forwarder[0].role == "roles/pubsub.subscriber"
    error_message = "Dead-letter forwarding must grant the Pub/Sub service agent subscriber access on the source subscription."
  }

  assert {
    condition     = google_pubsub_subscription.dead_letter[0].name == "orders-worker-dead-letter"
    error_message = "A DLQ inspection subscription must be created by default."
  }
}
