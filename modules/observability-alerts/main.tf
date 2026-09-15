locals {
  common_labels = merge(
    {
      environment = var.environment
      managed_by  = "terraform"
    },
    var.labels,
  )

  notification_channels = sort(tolist(var.notification_channels))
}

resource "google_monitoring_alert_policy" "cloud_run_server_errors" {
  for_each = var.cloud_run_services

  project      = var.project_id
  display_name = "[${var.environment}] Cloud Run ${each.key} 5xx ratio"
  combiner     = "OR"
  enabled      = var.enabled
  severity     = "ERROR"

  conditions {
    display_name = "5xx responses exceed ${var.thresholds.cloud_run_server_error_ratio * 100}%"

    condition_threshold {
      filter = "metric.type=\"run.googleapis.com/request_count\" AND resource.type=\"cloud_run_revision\" AND resource.label.\"location\"=\"${var.location}\" AND resource.label.\"service_name\"=\"${each.value}\" AND metric.label.\"response_code_class\"=\"5xx\""

      denominator_filter = "metric.type=\"run.googleapis.com/request_count\" AND resource.type=\"cloud_run_revision\" AND resource.label.\"location\"=\"${var.location}\" AND resource.label.\"service_name\"=\"${each.value}\""

      comparison      = "COMPARISON_GT"
      threshold_value = var.thresholds.cloud_run_server_error_ratio
      duration        = "300s"

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }

      denominator_aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }

      evaluation_missing_data = "EVALUATION_MISSING_DATA_INACTIVE"

      trigger {
        count = 1
      }
    }
  }

  documentation {
    content   = "Cloud Run service `${each.value}` has sustained a server-error ratio above the configured threshold for five minutes. Inspect recent revisions, application logs, downstream dependencies, and request latency before changing capacity."
    mime_type = "text/markdown"
  }

  notification_channels = local.notification_channels

  alert_strategy {
    auto_close = "1800s"
  }

  user_labels = merge(local.common_labels, {
    component = each.key
    signal    = "server-errors"
  })

  deletion_policy = "DELETE"
}

resource "google_monitoring_alert_policy" "pubsub_backlog_age" {
  count = var.pubsub_subscription_name == null ? 0 : 1

  project      = var.project_id
  display_name = "[${var.environment}] Pub/Sub oldest unacked message"
  combiner     = "OR"
  enabled      = var.enabled
  severity     = "WARNING"

  conditions {
    display_name = "Oldest unacked message exceeds ${var.thresholds.pubsub_oldest_unacked_age_seconds}s"

    condition_threshold {
      filter = "metric.type=\"pubsub.googleapis.com/subscription/oldest_unacked_message_age\" AND resource.type=\"pubsub_subscription\" AND resource.label.\"subscription_id\"=\"${var.pubsub_subscription_name}\""

      comparison      = "COMPARISON_GT"
      threshold_value = var.thresholds.pubsub_oldest_unacked_age_seconds
      duration        = "300s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MAX"
      }

      evaluation_missing_data = "EVALUATION_MISSING_DATA_INACTIVE"

      trigger {
        count = 1
      }
    }
  }

  documentation {
    content   = "The primary Pub/Sub subscription `${var.pubsub_subscription_name}` has a persistently old unacknowledged message. Inspect worker health, push delivery failures, subscriber throughput, retry behavior, and downstream dependencies."
    mime_type = "text/markdown"
  }

  notification_channels = local.notification_channels

  alert_strategy {
    auto_close = "1800s"
  }

  user_labels = merge(local.common_labels, {
    component = "messaging"
    signal    = "backlog-age"
  })

  deletion_policy = "DELETE"
}

resource "google_monitoring_alert_policy" "pubsub_dead_letter_forwarding" {
  count = var.pubsub_subscription_name == null ? 0 : 1

  project      = var.project_id
  display_name = "[${var.environment}] Pub/Sub dead-letter forwarding"
  combiner     = "OR"
  enabled      = var.enabled
  severity     = "ERROR"

  conditions {
    display_name = "Messages forwarded to dead-letter handling"

    condition_threshold {
      filter = "metric.type=\"pubsub.googleapis.com/subscription/dead_letter_message_count\" AND resource.type=\"pubsub_subscription\" AND resource.label.\"subscription_id\"=\"${var.pubsub_subscription_name}\""

      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "0s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_DELTA"
      }

      evaluation_missing_data = "EVALUATION_MISSING_DATA_INACTIVE"

      trigger {
        count = 1
      }
    }
  }

  documentation {
    content   = "Pub/Sub forwarded one or more undeliverable messages from `${var.pubsub_subscription_name}` to dead-letter handling. Inspect the failed message path, worker logs, delivery attempts, and the dead-letter inspection subscription before replaying data."
    mime_type = "text/markdown"
  }

  notification_channels = local.notification_channels

  alert_strategy {
    auto_close = "1800s"
  }

  user_labels = merge(local.common_labels, {
    component = "messaging"
    signal    = "dead-letter"
  })

  deletion_policy = "DELETE"
}

resource "google_monitoring_alert_policy" "cloud_run_job_failure" {
  count = var.cloud_run_job_name == null ? 0 : 1

  project      = var.project_id
  display_name = "[${var.environment}] Cloud Run Job failed execution"
  combiner     = "OR"
  enabled      = var.enabled
  severity     = "ERROR"

  conditions {
    display_name = "Completed execution reports failure"

    condition_threshold {
      filter = "metric.type=\"run.googleapis.com/job/completed_execution_count\" AND resource.type=\"cloud_run_job\" AND resource.label.\"location\"=\"${var.location}\" AND resource.label.\"job_name\"=\"${var.cloud_run_job_name}\" AND metric.label.\"result\"=\"failed\""

      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "0s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_DELTA"
      }

      evaluation_missing_data = "EVALUATION_MISSING_DATA_INACTIVE"

      trigger {
        count = 1
      }
    }
  }

  documentation {
    content   = "Cloud Run Job `${var.cloud_run_job_name}` reported a failed execution. Inspect the execution and task logs, exit code, retries, Secret Manager access, VPC connectivity, and downstream dependency health."
    mime_type = "text/markdown"
  }

  notification_channels = local.notification_channels

  alert_strategy {
    auto_close = "1800s"
  }

  user_labels = merge(local.common_labels, {
    component = "batch"
    signal    = "job-failure"
  })

  deletion_policy = "DELETE"
}

resource "google_monitoring_alert_policy" "redis_memory_pressure" {
  count = var.redis_instance_id == null ? 0 : 1

  project      = var.project_id
  display_name = "[${var.environment}] Redis memory pressure"
  combiner     = "OR"
  enabled      = var.enabled
  severity     = "WARNING"

  conditions {
    display_name = "Redis data memory usage exceeds ${var.thresholds.redis_memory_usage_ratio * 100}%"

    condition_threshold {
      filter = "metric.type=\"redis.googleapis.com/stats/memory/usage_ratio\" AND resource.type=\"redis_instance\" AND resource.label.\"region\"=\"${var.location}\" AND resource.label.\"instance_id\"=\"${var.redis_instance_id}\""

      comparison      = "COMPARISON_GT"
      threshold_value = var.thresholds.redis_memory_usage_ratio
      duration        = "300s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MAX"
      }

      evaluation_missing_data = "EVALUATION_MISSING_DATA_INACTIVE"

      trigger {
        count = 1
      }
    }
  }

  conditions {
    display_name = "Redis system memory usage exceeds ${var.thresholds.redis_system_memory_usage_ratio * 100}%"

    condition_threshold {
      filter = "metric.type=\"redis.googleapis.com/stats/memory/system_memory_usage_ratio\" AND resource.type=\"redis_instance\" AND resource.label.\"region\"=\"${var.location}\" AND resource.label.\"instance_id\"=\"${var.redis_instance_id}\""

      comparison      = "COMPARISON_GT"
      threshold_value = var.thresholds.redis_system_memory_usage_ratio
      duration        = "300s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MAX"
      }

      evaluation_missing_data = "EVALUATION_MISSING_DATA_INACTIVE"

      trigger {
        count = 1
      }
    }
  }

  documentation {
    content   = "Memorystore instance `${var.redis_instance_id}` is under sustained memory pressure. Inspect data memory, system memory, eviction policy, key growth, client behavior, and capacity before resizing or changing application caching behavior."
    mime_type = "text/markdown"
  }

  notification_channels = local.notification_channels

  alert_strategy {
    auto_close = "1800s"
  }

  user_labels = merge(local.common_labels, {
    component = "cache"
    signal    = "memory-pressure"
  })

  deletion_policy = "DELETE"
}

resource "google_monitoring_alert_policy" "redis_rejected_connections" {
  count = var.redis_instance_id == null ? 0 : 1

  project      = var.project_id
  display_name = "[${var.environment}] Redis rejected connections"
  combiner     = "OR"
  enabled      = var.enabled
  severity     = "ERROR"

  conditions {
    display_name = "Redis rejected one or more client connections"

    condition_threshold {
      filter = "metric.type=\"redis.googleapis.com/stats/reject_connections_count\" AND resource.type=\"redis_instance\" AND resource.label.\"region\"=\"${var.location}\" AND resource.label.\"instance_id\"=\"${var.redis_instance_id}\""

      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "0s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_DELTA"
      }

      evaluation_missing_data = "EVALUATION_MISSING_DATA_INACTIVE"

      trigger {
        count = 1
      }
    }
  }

  documentation {
    content   = "Memorystore instance `${var.redis_instance_id}` rejected client connections. Inspect maxclients pressure, client connection pooling, memory pressure, TLS/auth failures, and recent workload scaling."
    mime_type = "text/markdown"
  }

  notification_channels = local.notification_channels

  alert_strategy {
    auto_close = "1800s"
  }

  user_labels = merge(local.common_labels, {
    component = "cache"
    signal    = "rejected-connections"
  })

  deletion_policy = "DELETE"
}
