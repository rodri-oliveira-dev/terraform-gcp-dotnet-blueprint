mock_provider "google" {
  override_during = plan
}

variables {
  project_id      = "example-project"
  name            = "example-batch"
  location        = "us-central1"
  container_image = "us-docker.pkg.dev/example-project/apps/batch:1.0.0"
  service_account = "batch-runtime@example-project.iam.gserviceaccount.com"
}

run "safe_defaults" {
  command = plan

  assert {
    condition     = google_cloud_run_v2_job.this.deletion_protection
    error_message = "Deletion protection must be enabled by default."
  }

  assert {
    condition = (
      google_cloud_run_v2_job.this.template[0].task_count == 1 &&
      google_cloud_run_v2_job.this.template[0].parallelism == 1
    )
    error_message = "The default job must use one task with parallelism one."
  }

  assert {
    condition = (
      google_cloud_run_v2_job.this.template[0].template[0].service_account == var.service_account &&
      google_cloud_run_v2_job.this.template[0].template[0].max_retries == 3 &&
      google_cloud_run_v2_job.this.template[0].template[0].timeout == "600s"
    )
    error_message = "Runtime identity, retry count and task timeout must use the documented defaults."
  }

  assert {
    condition = (
      google_cloud_run_v2_job.this.template[0].template[0].containers[0].resources[0].limits["cpu"] == "1" &&
      google_cloud_run_v2_job.this.template[0].template[0].containers[0].resources[0].limits["memory"] == "512Mi"
    )
    error_message = "The module must apply the documented default CPU and memory limits."
  }

  assert {
    condition     = output.execution_uri == "https://run.googleapis.com/v2/projects/example-project/locations/us-central1/jobs/example-batch:run"
    error_message = "execution_uri must expose the supported Cloud Run Admin API run endpoint."
  }
}

run "maps_literal_and_secret_environment_variables" {
  command = plan

  variables {
    environment_variables = {
      DOTNET_ENVIRONMENT = "Production"
    }
    secret_environment_variables = {
      API_KEY = {
        secret = "batch-api-key"
      }
    }
  }

  assert {
    condition     = length(google_cloud_run_v2_job.this.template[0].template[0].containers[0].env) == 2
    error_message = "Literal and Secret Manager-backed environment variables must both be rendered into the task container."
  }
}
