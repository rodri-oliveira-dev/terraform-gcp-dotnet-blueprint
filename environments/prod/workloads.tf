module "worker" {
  count  = var.enable_workloads ? 1 : 0
  source = "../../modules/cloud-run-service"

  project_id      = var.project_id
  name            = "${local.name_prefix}-worker"
  location        = var.region
  description     = "Production request-serving worker for authenticated Pub/Sub push delivery."
  container_image = var.worker_image
  service_account = module.worker_identity.email

  resources = {
    cpu    = "1"
    memory = "1Gi"
  }

  scaling = {
    min_instance_count = 1
    max_instance_count = 20
  }

  environment_variables = {
    DOTNET_ENVIRONMENT = "Production"
    REDIS_HOST         = module.cache.host
    REDIS_PORT         = tostring(module.cache.port)
    REDIS_TLS          = tostring(module.cache.connection.tls_enabled)
    WORKER_TRANSPORT   = "PubSubPush"
  }

  secret_environment_variables = {
    APP_CONFIG    = module.worker_config_secret.secret_reference
    REDIS_AUTH    = module.redis_auth_secret.secret_reference
    REDIS_CA_CERT = module.redis_ca_secret.secret_reference
  }

  direct_vpc = {
    network    = module.network.direct_vpc.network
    subnetwork = module.network.direct_vpc.subnetwork
    tags       = ["prod", "worker"]
  }

  labels = merge(local.common_labels, {
    component = "worker"
  })

  depends_on = [google_project_service.required]
}

resource "google_cloud_run_v2_service_iam_member" "pubsub_invoker" {
  count = var.enable_workloads ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = module.worker[0].name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.pubsub_push.email}"
}

module "events" {
  count  = var.enable_workloads ? 1 : 0
  source = "../../modules/pubsub"

  project_id        = var.project_id
  topic_name        = "${local.name_prefix}-events"
  subscription_name = "${local.name_prefix}-worker"

  push_config = {
    endpoint              = "${module.worker[0].uri}/"
    service_account_email = google_service_account.pubsub_push.email
    audience              = module.worker[0].uri
  }

  retry_policy = {
    minimum_backoff_seconds = 10
    maximum_backoff_seconds = 600
  }

  dead_letter = {
    max_delivery_attempts = 20
  }

  labels = merge(local.common_labels, {
    component = "messaging"
  })

  depends_on = [
    google_cloud_run_v2_service_iam_member.pubsub_invoker,
    google_project_service.required,
  ]
}

resource "google_pubsub_topic_iam_member" "api_publisher" {
  count = var.enable_workloads ? 1 : 0

  project = var.project_id
  topic   = module.events[0].topic_name
  role    = "roles/pubsub.publisher"
  member  = module.api_identity.member
}

module "api" {
  count  = var.enable_workloads ? 1 : 0
  source = "../../modules/cloud-run-service"

  project_id      = var.project_id
  name            = "${local.name_prefix}-api"
  location        = var.region
  description     = "Production .NET API. Invocation remains authenticated and non-public by default."
  container_image = var.api_image
  service_account = module.api_identity.email

  resources = {
    cpu    = "2"
    memory = "1Gi"
  }

  scaling = {
    min_instance_count = 1
    max_instance_count = 20
  }

  environment_variables = {
    ASPNETCORE_ENVIRONMENT = "Production"
    EVENTS_TOPIC           = module.events[0].topic_name
    REDIS_HOST             = module.cache.host
    REDIS_PORT             = tostring(module.cache.port)
    REDIS_TLS              = tostring(module.cache.connection.tls_enabled)
  }

  secret_environment_variables = {
    APP_CONFIG    = module.api_config_secret.secret_reference
    REDIS_AUTH    = module.redis_auth_secret.secret_reference
    REDIS_CA_CERT = module.redis_ca_secret.secret_reference
  }

  direct_vpc = {
    network    = module.network.direct_vpc.network
    subnetwork = module.network.direct_vpc.subnetwork
    tags       = ["api", "prod"]
  }

  labels = merge(local.common_labels, {
    component = "api"
  })

  depends_on = [
    google_project_service.required,
    google_pubsub_topic_iam_member.api_publisher,
  ]
}

module "batch" {
  count  = var.enable_workloads ? 1 : 0
  source = "../../modules/cloud-run-job"

  project_id      = var.project_id
  name            = "${local.name_prefix}-batch"
  location        = var.region
  container_image = var.batch_image
  service_account = module.batch_identity.email

  task_count   = 4
  parallelism  = 2
  max_retries  = 5
  task_timeout = "1800s"

  resources = {
    cpu    = "2"
    memory = "2Gi"
  }

  environment_variables = {
    DOTNET_ENVIRONMENT = "Production"
    REDIS_HOST         = module.cache.host
    REDIS_PORT         = tostring(module.cache.port)
    REDIS_TLS          = tostring(module.cache.connection.tls_enabled)
  }

  secret_environment_variables = {
    APP_CONFIG    = module.batch_config_secret.secret_reference
    REDIS_AUTH    = module.redis_auth_secret.secret_reference
    REDIS_CA_CERT = module.redis_ca_secret.secret_reference
  }

  direct_vpc = {
    network    = module.network.direct_vpc.network
    subnetwork = module.network.direct_vpc.subnetwork
    tags       = ["batch", "prod"]
  }

  labels = merge(local.common_labels, {
    component = "batch"
  })

  depends_on = [google_project_service.required]
}

resource "google_cloud_run_v2_job_iam_member" "scheduler_invoker" {
  count = var.enable_workloads ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = module.batch[0].name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.scheduler.email}"
}

resource "google_cloud_scheduler_job" "batch" {
  count = var.enable_workloads ? 1 : 0

  project          = var.project_id
  region           = var.region
  name             = "${local.name_prefix}-batch-trigger"
  description      = "Starts the production Cloud Run batch job through the Cloud Run Admin API."
  schedule         = var.scheduler_schedule
  time_zone        = var.scheduler_time_zone
  attempt_deadline = "320s"

  retry_config {
    retry_count = 5
  }

  http_target {
    http_method = "POST"
    uri         = module.batch[0].execution_uri
    body        = base64encode("{}")

    headers = {
      "Content-Type" = "application/json"
    }

    oauth_token {
      service_account_email = google_service_account.scheduler.email
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }

  depends_on = [
    google_cloud_run_v2_job_iam_member.scheduler_invoker,
    google_project_service.required,
  ]
}
