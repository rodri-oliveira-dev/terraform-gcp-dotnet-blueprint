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
