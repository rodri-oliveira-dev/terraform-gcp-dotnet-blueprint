mock_provider "google" {}

variables {
  project_id  = "example-project"
  environment = "dev"
  location    = "us-central1"

  cloud_run_services = {
    api    = "blueprint-dev-api"
    worker = "blueprint-dev-worker"
  }

  cloud_run_job_name        = "blueprint-dev-batch"
  pubsub_subscription_name  = "blueprint-dev-worker"
  redis_instance_id         = "blueprint-dev-cache"
  notification_channels     = ["projects/example-project/notificationChannels/123"]
}

run "creates_portable_alert_defaults" {
  command = plan

  assert {
    condition     = length(google_monitoring_alert_policy.cloud_run_server_errors) == 2
    error_message = "One Cloud Run server-error policy must be created for each configured service target."
  }

  assert {
    condition = (
      google_monitoring_alert_policy.cloud_run_server_errors["api"].enabled &&
      google_monitoring_alert_policy.cloud_run_server_errors["api"].severity == "ERROR" &&
      google_monitoring_alert_policy.cloud_run_server_errors["api"].notification_channels[0] == "projects/example-project/notificationChannels/123"
    )
    error_message = "Cloud Run server-error policies must be enabled and use caller-supplied notification channels."
  }

  assert {
    condition = (
      google_monitoring_alert_policy.cloud_run_server_errors["api"].conditions[0].condition_threshold[0].threshold_value == 0.05 &&
      strcontains(google_monitoring_alert_policy.cloud_run_server_errors["api"].conditions[0].condition_threshold[0].filter, "response_code_class") &&
      strcontains(google_monitoring_alert_policy.cloud_run_server_errors["api"].conditions[0].condition_threshold[0].denominator_filter, "blueprint-dev-api")
    )
    error_message = "Cloud Run policies must compare the 5xx request ratio against the default 5% threshold."
  }

  assert {
    condition = (
      strcontains(google_monitoring_alert_policy.pubsub_backlog_age[0].conditions[0].condition_threshold[0].filter, "oldest_unacked_message_age") &&
      google_monitoring_alert_policy.pubsub_backlog_age[0].conditions[0].condition_threshold[0].threshold_value == 300
    )
    error_message = "Pub/Sub backlog age must use the official oldest-unacked-message metric and the default 300 second threshold."
  }

  assert {
    condition = strcontains(
      google_monitoring_alert_policy.pubsub_dead_letter_forwarding[0].conditions[0].condition_threshold[0].filter,
      "dead_letter_message_count",
    )
    error_message = "Dead-letter alerting must use Pub/Sub's direct forwarding metric on the primary subscription."
  }

  assert {
    condition = (
      strcontains(google_monitoring_alert_policy.cloud_run_job_failure[0].conditions[0].condition_threshold[0].filter, "completed_execution_count") &&
      strcontains(google_monitoring_alert_policy.cloud_run_job_failure[0].conditions[0].condition_threshold[0].filter, "failed")
    )
    error_message = "Cloud Run Job alerting must target failed completed executions."
  }

  assert {
    condition = (
      length(google_monitoring_alert_policy.redis_memory_pressure[0].conditions) == 2 &&
      google_monitoring_alert_policy.redis_memory_pressure[0].conditions[0].condition_threshold[0].threshold_value == 0.80 &&
      google_monitoring_alert_policy.redis_memory_pressure[0].conditions[1].condition_threshold[0].threshold_value == 0.80
    )
    error_message = "Redis memory pressure must cover data memory and system memory with 80% defaults."
  }

  assert {
    condition = strcontains(
      google_monitoring_alert_policy.redis_rejected_connections[0].conditions[0].condition_threshold[0].filter,
      "reject_connections_count",
    )
    error_message = "Redis rejected connections must be monitored with the native rejected-connection metric."
  }
}

run "supports_no_optional_targets" {
  command = plan

  variables {
    cloud_run_services         = {}
    cloud_run_job_name         = null
    pubsub_subscription_name   = null
    redis_instance_id          = null
    notification_channels      = []
  }

  assert {
    condition = (
      length(google_monitoring_alert_policy.cloud_run_server_errors) == 0 &&
      length(google_monitoring_alert_policy.cloud_run_job_failure) == 0 &&
      length(google_monitoring_alert_policy.pubsub_backlog_age) == 0 &&
      length(google_monitoring_alert_policy.pubsub_dead_letter_forwarding) == 0 &&
      length(google_monitoring_alert_policy.redis_memory_pressure) == 0 &&
      length(google_monitoring_alert_policy.redis_rejected_connections) == 0
    )
    error_message = "Optional targets must not create alert policies when omitted."
  }
}
