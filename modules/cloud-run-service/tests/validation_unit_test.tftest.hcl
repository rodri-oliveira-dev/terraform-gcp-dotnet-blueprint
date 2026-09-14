mock_provider "google" {}

variables {
  project_id      = "example-project"
  name            = "example-api"
  location        = "us-central1"
  container_image = "us-docker.pkg.dev/example-project/apps/api:1.0.0"
  service_account = "cloud-run-api@example-project.iam.gserviceaccount.com"
}

run "reject_invalid_concurrency" {
  command = plan

  variables {
    max_instance_request_concurrency = 1001
  }

  expect_failures = [
    var.max_instance_request_concurrency,
  ]
}

run "reject_invalid_scaling_range" {
  command = plan

  variables {
    scaling = {
      min_instance_count = 5
      max_instance_count = 2
    }
  }

  expect_failures = [
    var.scaling,
  ]
}

run "reject_unsupported_cpu" {
  command = plan

  variables {
    resources = {
      cpu    = "3"
      memory = "1Gi"
    }
  }

  expect_failures = [
    var.resources,
  ]
}

run "reject_memory_below_platform_minimum" {
  command = plan

  variables {
    resources = {
      cpu    = "1"
      memory = "256Mi"
    }
  }

  expect_failures = [
    var.resources,
  ]
}

run "reject_memory_above_platform_maximum" {
  command = plan

  variables {
    resources = {
      cpu    = "8"
      memory = "64Gi"
    }
  }

  expect_failures = [
    var.resources,
  ]
}

run "reject_incompatible_cpu_memory_pair" {
  command = plan

  variables {
    resources = {
      cpu    = "4"
      memory = "1Gi"
    }
  }

  expect_failures = [
    var.resources,
  ]
}

run "reject_reserved_literal_environment_name" {
  command = plan

  variables {
    environment_variables = {
      PORT = "8080"
    }
  }

  expect_failures = [
    var.environment_variables,
  ]
}

run "reject_reserved_google_environment_prefix" {
  command = plan

  variables {
    environment_variables = {
      X_GOOGLE_TEST = "value"
    }
  }

  expect_failures = [
    var.environment_variables,
  ]
}

run "reject_reserved_secret_environment_name" {
  command = plan

  variables {
    secret_environment_variables = {
      PORT = {
        secret = "api-port"
      }
    }
  }

  expect_failures = [
    var.secret_environment_variables,
  ]
}

run "reject_duplicate_environment_names" {
  command = plan

  variables {
    environment_variables = {
      API_KEY = "literal-value"
    }
    secret_environment_variables = {
      API_KEY = {
        secret = "api-key"
      }
    }
  }

  expect_failures = [
    google_cloud_run_v2_service.this,
  ]
}
