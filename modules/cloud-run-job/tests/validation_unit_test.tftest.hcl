mock_provider "google" {}

variables {
  project_id      = "example-project"
  name            = "example-batch"
  location        = "us-central1"
  container_image = "us-docker.pkg.dev/example-project/apps/batch:1.0.0"
  service_account = "batch-runtime@example-project.iam.gserviceaccount.com"
}

run "reject_parallelism_above_task_count" {
  command = plan

  variables {
    task_count  = 2
    parallelism = 3
  }

  expect_failures = [
    var.parallelism,
  ]
}

run "reject_task_count_above_platform_limit" {
  command = plan

  variables {
    task_count = 10001
  }

  expect_failures = [
    var.task_count,
  ]
}

run "reject_retries_above_platform_limit" {
  command = plan

  variables {
    max_retries = 11
  }

  expect_failures = [
    var.max_retries,
  ]
}

run "reject_task_timeout_above_platform_limit" {
  command = plan

  variables {
    task_timeout = "604801s"
  }

  expect_failures = [
    var.task_timeout,
  ]
}

run "reject_cpu_requiring_explicit_gen2" {
  command = plan

  variables {
    resources = {
      cpu    = "8"
      memory = "4Gi"
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

run "reject_cloud_run_reserved_environment_name" {
  command = plan

  variables {
    environment_variables = {
      CLOUD_RUN_TASK_INDEX = "0"
    }
  }

  expect_failures = [
    var.environment_variables,
  ]
}

run "reject_google_reserved_secret_environment_name" {
  command = plan

  variables {
    secret_environment_variables = {
      X_GOOGLE_TOKEN = {
        secret = "token"
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
    google_cloud_run_v2_job.this,
  ]
}
