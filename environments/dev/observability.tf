module "observability" {
  count  = var.enable_workloads ? 1 : 0
  source = "../../modules/observability-alerts"

  project_id  = var.project_id
  environment = local.environment
  location    = var.region

  cloud_run_services = {
    api    = module.api[0].name
    worker = module.worker[0].name
  }

  cloud_run_job_name       = module.batch[0].name
  pubsub_subscription_name = module.events[0].subscription_name
  redis_instance_id        = module.cache.name
  notification_channels    = var.observability_notification_channels
  thresholds               = var.observability_thresholds

  labels = {
    application = var.application_name
  }

  depends_on = [google_project_service.required]
}
