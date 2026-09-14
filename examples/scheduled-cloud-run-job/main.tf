module "batch" {
  source = "../../modules/cloud-run-job"

  project_id      = var.project_id
  name            = "example-nightly-batch"
  location        = var.location
  container_image = var.container_image
  service_account = var.runtime_service_account

  task_count   = 4
  parallelism  = 2
  max_retries  = 3
  task_timeout = "1800s"

  resources = {
    cpu    = "1"
    memory = "1Gi"
  }

  environment_variables = {
    DOTNET_ENVIRONMENT = "Production"
  }

  labels = {
    component = "batch"
    pattern   = "scheduled-job"
  }
}

resource "google_cloud_run_v2_job_iam_member" "scheduler_invoker" {
  project  = var.project_id
  location = var.location
  name     = module.batch.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${var.scheduler_service_account}"
}

resource "google_cloud_scheduler_job" "batch" {
  project          = var.project_id
  region           = var.location
  name             = "example-nightly-batch-trigger"
  description      = "Starts the example Cloud Run batch job through the Cloud Run Admin API."
  schedule         = var.schedule
  time_zone        = var.time_zone
  attempt_deadline = "320s"

  retry_config {
    retry_count = 3
  }

  http_target {
    http_method = "POST"
    uri         = module.batch.execution_uri
    body        = base64encode("{}")

    headers = {
      "Content-Type" = "application/json"
    }

    oauth_token {
      service_account_email = var.scheduler_service_account
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }

  depends_on = [
    google_cloud_run_v2_job_iam_member.scheduler_invoker,
  ]

  lifecycle {
    precondition {
      condition     = var.runtime_service_account != var.scheduler_service_account
      error_message = "Use separate runtime and scheduler service accounts so execution identity and trigger identity remain independently scoped."
    }
  }
}
