mock_provider "google" {}

variables {
  project_id  = "example-project"
  environment = "dev"
  location    = "us-central1"
}

run "reject_invalid_environment" {
  command = plan

  variables {
    environment = "DEV"
  }

  expect_failures = [
    var.environment,
  ]
}

run "reject_invalid_cloud_run_service_name" {
  command = plan

  variables {
    cloud_run_services = {
      api = "Blueprint_API"
    }
  }

  expect_failures = [
    var.cloud_run_services,
  ]
}

run "reject_invalid_cloud_run_target_key" {
  command = plan

  variables {
    cloud_run_services = {
      "API Service" = "blueprint-api"
    }
  }

  expect_failures = [
    var.cloud_run_services,
  ]
}

run "reject_invalid_job_name" {
  command = plan

  variables {
    cloud_run_job_name = "Batch_Job"
  }

  expect_failures = [
    var.cloud_run_job_name,
  ]
}

run "reject_invalid_subscription_name" {
  command = plan

  variables {
    pubsub_subscription_name = "go"
  }

  expect_failures = [
    var.pubsub_subscription_name,
  ]
}

run "reject_invalid_redis_instance_id" {
  command = plan

  variables {
    redis_instance_id = "Redis_Cache"
  }

  expect_failures = [
    var.redis_instance_id,
  ]
}

run "reject_malformed_notification_channel" {
  command = plan

  variables {
    notification_channels = ["email:platform@example.com"]
  }

  expect_failures = [
    var.notification_channels,
  ]
}

run "reject_server_error_ratio_above_one" {
  command = plan

  variables {
    thresholds = {
      cloud_run_server_error_ratio = 1.01
    }
  }

  expect_failures = [
    var.thresholds,
  ]
}

run "reject_too_small_backlog_age" {
  command = plan

  variables {
    thresholds = {
      pubsub_oldest_unacked_age_seconds = 30
    }
  }

  expect_failures = [
    var.thresholds,
  ]
}

run "reject_invalid_redis_memory_ratio" {
  command = plan

  variables {
    thresholds = {
      redis_memory_usage_ratio = 0
    }
  }

  expect_failures = [
    var.thresholds,
  ]
}

run "reject_invalid_user_label" {
  command = plan

  variables {
    labels = {
      "Owner" = "Platform Team"
    }
  }

  expect_failures = [
    var.labels,
  ]
}
