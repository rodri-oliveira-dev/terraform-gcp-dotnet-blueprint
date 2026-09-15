module "alerts" {
  source = "../../modules/observability-alerts"

  project_id  = var.project_id
  environment = "example"
  location    = var.location

  cloud_run_services = {
    api    = "example-api"
    worker = "example-worker"
  }

  cloud_run_job_name       = "example-batch"
  pubsub_subscription_name = "example-worker"
  redis_instance_id        = "example-cache"

  notification_channels = var.notification_channels

  labels = {
    owner = "platform"
  }
}
