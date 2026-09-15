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
}

run "reject_ack_deadline_below_platform_minimum" {
  command = plan

  variables {
    ack_deadline_seconds = 9
  }

  expect_failures = [
    var.ack_deadline_seconds,
  ]
}

run "reject_message_retention_above_platform_maximum" {
  command = plan

  variables {
    message_retention_seconds = 2678401
  }

  expect_failures = [
    var.message_retention_seconds,
  ]
}

run "reject_inverted_retry_backoff" {
  command = plan

  variables {
    retry_policy = {
      minimum_backoff_seconds = 120
      maximum_backoff_seconds = 60
    }
  }

  expect_failures = [
    var.retry_policy,
  ]
}

run "reject_dead_letter_attempts_below_platform_minimum" {
  command = plan

  variables {
    dead_letter = {
      max_delivery_attempts = 4
    }
  }

  expect_failures = [
    var.dead_letter,
  ]
}

run "reject_reserved_topic_prefix" {
  command = plan

  variables {
    topic_name = "goog-orders-events"
  }

  expect_failures = [
    var.topic_name,
  ]
}

run "reject_non_ascii_filter" {
  command = plan

  variables {
    filter = "attributes.kind = \"ação\""
  }

  expect_failures = [
    var.filter,
  ]
}

run "reject_filter_over_256_bytes" {
  command = plan

  variables {
    filter = join("", [for i in range(257) : "a"])
  }

  expect_failures = [
    var.filter,
  ]
}

run "reject_generated_dead_letter_topic_name_over_255_characters" {
  command = plan

  variables {
    topic_name = join("", concat(["a"], [for i in range(243) : "b"]))
  }

  expect_failures = [
    google_pubsub_subscription.primary,
  ]
}

run "reject_generated_dead_letter_subscription_name_over_255_characters" {
  command = plan

  variables {
    subscription_name = join("", concat(["a"], [for i in range(243) : "b"]))
  }

  expect_failures = [
    google_pubsub_subscription.primary,
  ]
}

run "reject_non_https_push_endpoint" {
  command = plan

  variables {
    push_config = {
      endpoint              = "http://worker.example.test/"
      service_account_email = "orders-push@example-project.iam.gserviceaccount.com"
    }
  }

  expect_failures = [
    var.push_config,
  ]
}

run "reject_metadata_without_payload_unwrapping" {
  command = plan

  variables {
    push_config = {
      endpoint              = "https://orders-worker-abc.run.app/"
      service_account_email = "orders-push@example-project.iam.gserviceaccount.com"
      no_wrapper            = false
      write_metadata        = true
    }
  }

  expect_failures = [
    var.push_config,
  ]
}

run "reject_cross_project_push_identity" {
  command = plan

  variables {
    push_config = {
      endpoint              = "https://orders-worker-abc.run.app/"
      service_account_email = "orders-push@other-project.iam.gserviceaccount.com"
    }
  }

  expect_failures = [
    google_pubsub_subscription.primary,
  ]
}

run "reject_primary_topic_as_dead_letter_topic" {
  command = plan

  variables {
    dead_letter = {
      topic_name = "orders-events"
    }
  }

  expect_failures = [
    google_pubsub_subscription.primary,
  ]
}
