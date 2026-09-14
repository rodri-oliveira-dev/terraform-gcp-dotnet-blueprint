mock_provider "google" {
  override_during = plan

  mock_resource "google_cloud_run_v2_service" {
    defaults = {
      uri = "https://example-api-test.run.app"
    }
  }
}

variables {
  project_id      = "example-project"
  name            = "example-api"
  location        = "us-central1"
  container_image = "us-docker.pkg.dev/example-project/apps/api:1.0.0"
  service_account = "cloud-run-api@example-project.iam.gserviceaccount.com"
}

run "secure_defaults" {
  command = plan

  assert {
    condition     = google_cloud_run_v2_service.this.ingress == "INGRESS_TRAFFIC_INTERNAL_ONLY"
    error_message = "The module must default to internal-only ingress."
  }

  assert {
    condition     = google_cloud_run_v2_service.this.deletion_protection
    error_message = "Deletion protection must be enabled by default."
  }

  assert {
    condition     = google_cloud_run_v2_service.this.template[0].service_account == var.service_account
    error_message = "The configured runtime service account must be assigned to the revision."
  }

  assert {
    condition     = google_cloud_run_v2_service.this.template[0].max_instance_request_concurrency == 80
    error_message = "The default per-instance concurrency must be 80."
  }

  assert {
    condition = (
      google_cloud_run_v2_service.this.template[0].scaling[0].min_instance_count == 0 &&
      google_cloud_run_v2_service.this.template[0].scaling[0].max_instance_count == 10
    )
    error_message = "The default scaling range must be zero through ten instances."
  }

  assert {
    condition = (
      google_cloud_run_v2_service.this.template[0].containers[0].resources[0].limits["cpu"] == "1" &&
      google_cloud_run_v2_service.this.template[0].containers[0].resources[0].limits["memory"] == "512Mi"
    )
    error_message = "The module must apply the documented default CPU and memory limits."
  }

  assert {
    condition     = output.uri == "https://example-api-test.run.app"
    error_message = "The service URI output must forward the provider-computed URI."
  }
}

run "maps_literal_and_secret_environment_variables" {
  command = plan

  variables {
    environment_variables = {
      ASPNETCORE_ENVIRONMENT = "Production"
    }
    secret_environment_variables = {
      API_KEY = {
        secret  = "api-key"
        version = "latest"
      }
    }
  }

  assert {
    condition     = length(google_cloud_run_v2_service.this.template[0].containers[0].env) == 2
    error_message = "Literal and Secret Manager-backed environment variables must both be rendered into the container configuration."
  }
}
