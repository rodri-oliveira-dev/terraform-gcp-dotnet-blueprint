data "google_project" "current" {
  project_id = var.project_id
}

locals {
  dead_letter_topic_name = coalesce(
    var.dead_letter.topic_name,
    "${var.topic_name}-dead-letter",
  )
  dead_letter_subscription_name = coalesce(
    var.dead_letter.subscription_name,
    "${var.subscription_name}-dead-letter",
  )
  pubsub_service_agent_email  = "service-${data.google_project.current.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
  pubsub_service_agent_member = "serviceAccount:${local.pubsub_service_agent_email}"
  push_service_account_resource = var.push_config == null ? (
    "projects/${var.project_id}/serviceAccounts/unused@${var.project_id}.iam.gserviceaccount.com"
    ) : (
    "projects/${var.project_id}/serviceAccounts/${var.push_config.service_account_email}"
  )
}

resource "google_pubsub_topic" "primary" {
  project = var.project_id
  name    = var.topic_name
  labels  = var.labels
}

resource "google_pubsub_topic" "dead_letter" {
  count = var.dead_letter.enabled ? 1 : 0

  project = var.project_id
  name    = local.dead_letter_topic_name
  labels  = merge(var.labels, { purpose = "dead-letter" })
}

resource "google_service_account_iam_member" "push_token_creator" {
  count = var.manage_service_agent_iam && var.push_config != null ? 1 : 0

  service_account_id = local.push_service_account_resource
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = local.pubsub_service_agent_member
}

resource "google_pubsub_subscription" "primary" {
  project = var.project_id
  name    = var.subscription_name
  topic   = google_pubsub_topic.primary.id
  labels  = var.labels

  ack_deadline_seconds       = var.ack_deadline_seconds
  message_retention_duration = "${var.message_retention_seconds}s"
  retain_acked_messages      = var.retain_acked_messages
  enable_message_ordering    = var.enable_message_ordering
  filter                     = var.filter

  expiration_policy {
    ttl = ""
  }

  retry_policy {
    minimum_backoff = "${var.retry_policy.minimum_backoff_seconds}s"
    maximum_backoff = "${var.retry_policy.maximum_backoff_seconds}s"
  }

  dynamic "dead_letter_policy" {
    for_each = var.dead_letter.enabled ? [var.dead_letter] : []

    content {
      dead_letter_topic     = google_pubsub_topic.dead_letter[0].id
      max_delivery_attempts = dead_letter_policy.value.max_delivery_attempts
    }
  }

  dynamic "push_config" {
    for_each = var.push_config == null ? [] : [var.push_config]

    content {
      push_endpoint = push_config.value.endpoint

      attributes = {
        x-goog-version = "v1"
      }

      oidc_token {
        service_account_email = push_config.value.service_account_email
        audience              = push_config.value.audience
      }

      dynamic "no_wrapper" {
        for_each = push_config.value.no_wrapper ? [1] : []

        content {
          write_metadata = push_config.value.write_metadata
        }
      }
    }
  }

  lifecycle {
    precondition {
      condition = (
        !var.dead_letter.enabled ||
        length(local.dead_letter_topic_name) <= 255
      )
      error_message = "The dead-letter topic name must not exceed 255 characters; provide dead_letter.topic_name explicitly when the generated name would overflow."
    }

    precondition {
      condition = (
        !var.dead_letter.enabled ||
        !var.dead_letter.create_inspection_subscription ||
        length(local.dead_letter_subscription_name) <= 255
      )
      error_message = "The dead-letter inspection subscription name must not exceed 255 characters; provide dead_letter.subscription_name explicitly when the generated name would overflow."
    }

    precondition {
      condition = (
        !var.dead_letter.enabled ||
        local.dead_letter_topic_name != var.topic_name
      )
      error_message = "The dead-letter topic must be different from the primary topic."
    }

    precondition {
      condition = (
        !var.dead_letter.enabled ||
        !var.dead_letter.create_inspection_subscription ||
        local.dead_letter_subscription_name != var.subscription_name
      )
      error_message = "The dead-letter inspection subscription must be different from the primary subscription."
    }

    precondition {
      condition = (
        var.push_config == null ||
        endswith(
          var.push_config.service_account_email,
          "@${var.project_id}.iam.gserviceaccount.com",
        )
      )
      error_message = "The authenticated push service account must belong to the same project as the Pub/Sub subscription."
    }
  }

  depends_on = [
    google_service_account_iam_member.push_token_creator,
  ]
}

resource "google_pubsub_topic_iam_member" "dead_letter_publisher" {
  count = var.manage_service_agent_iam && var.dead_letter.enabled ? 1 : 0

  project = var.project_id
  topic   = google_pubsub_topic.dead_letter[0].name
  role    = "roles/pubsub.publisher"
  member  = local.pubsub_service_agent_member
}

resource "google_pubsub_subscription_iam_member" "dead_letter_forwarder" {
  count = var.manage_service_agent_iam && var.dead_letter.enabled ? 1 : 0

  project      = var.project_id
  subscription = google_pubsub_subscription.primary.name
  role         = "roles/pubsub.subscriber"
  member       = local.pubsub_service_agent_member
}

resource "google_pubsub_subscription" "dead_letter" {
  count = var.dead_letter.enabled && var.dead_letter.create_inspection_subscription ? 1 : 0

  project = var.project_id
  name    = local.dead_letter_subscription_name
  topic   = google_pubsub_topic.dead_letter[0].id
  labels  = merge(var.labels, { purpose = "dead-letter" })

  ack_deadline_seconds       = var.ack_deadline_seconds
  message_retention_duration = "${var.message_retention_seconds}s"
  retain_acked_messages      = var.retain_acked_messages

  expiration_policy {
    ttl = ""
  }
}
