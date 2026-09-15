locals {
  environment = "prod"
  name_prefix = "${var.application_name}-${local.environment}"

  common_labels = merge(
    {
      application = var.application_name
      environment = local.environment
      managed-by  = "terraform"
    },
    var.labels,
  )

  required_services = toset([
    "cloudresourcemanager.googleapis.com",
    "cloudscheduler.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "monitoring.googleapis.com",
    "pubsub.googleapis.com",
    "redis.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "servicenetworking.googleapis.com",
  ])
}
