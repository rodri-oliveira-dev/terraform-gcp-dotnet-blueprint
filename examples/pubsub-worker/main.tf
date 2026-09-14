module "worker" {
  source = "../../modules/cloud-run-service"

  project_id      = var.project_id
  name            = "orders-worker"
  location        = var.location
  description     = "Request-serving .NET worker that receives authenticated Pub/Sub push deliveries."
  container_image = var.worker_image
  service_account = var.worker_runtime_service_account

  resources = {
    cpu    = "1"
    memory = "512Mi"
  }

  scaling = {
    min_instance_count = 0
    max_instance_count = 10
  }

  environment_variables = {
    WORKER_TRANSPORT = "PubSubPush"
  }

  labels = {
    component  = "worker"
    managed-by = "terraform"
  }
}

resource "google_cloud_run_v2_service_iam_member" "pubsub_invoker" {
  project  = var.project_id
  location = var.location
  name     = module.worker.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${var.push_service_account}"
}

module "events" {
  source = "../../modules/pubsub"

  project_id        = var.project_id
  topic_name        = "orders-events"
  subscription_name = "orders-worker"

  push_config = {
    endpoint              = "${module.worker.uri}/"
    service_account_email = var.push_service_account
    audience              = module.worker.uri
  }

  retry_policy = {
    minimum_backoff_seconds = 10
    maximum_backoff_seconds = 300
  }

  dead_letter = {
    max_delivery_attempts = 10
  }

  labels = {
    component  = "worker"
    managed-by = "terraform"
  }

  depends_on = [
    google_cloud_run_v2_service_iam_member.pubsub_invoker,
  ]
}
