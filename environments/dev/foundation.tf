resource "google_project_service" "required" {
  for_each = local.required_services

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

module "network" {
  source = "../../modules/vpc-network"

  project_id   = var.project_id
  network_name = "${local.name_prefix}-vpc"

  subnet_name          = "${local.name_prefix}-${var.region}"
  subnet_region        = var.region
  subnet_ip_cidr_range = var.subnet_ip_cidr_range

  private_service_access_range_name = "${local.name_prefix}-managed-services"
  private_service_access_cidr       = var.private_service_access_cidr

  depends_on = [google_project_service.required]
}

module "cache" {
  source = "../../modules/memorystore-redis"

  project_id         = var.project_id
  name               = "${local.name_prefix}-cache"
  region             = var.region
  authorized_network = module.network.network_id

  tier           = "BASIC"
  memory_size_gb = 1

  labels = merge(local.common_labels, {
    component = "cache"
  })

  depends_on = [
    google_project_service.required,
    module.network,
  ]
}

module "api_identity" {
  source = "../../modules/runtime-identity"

  project_id   = var.project_id
  account_id   = "${local.name_prefix}-api"
  display_name = "${local.name_prefix} API runtime"
  description  = "Development runtime identity for the request-serving API."

  depends_on = [google_project_service.required]
}

module "worker_identity" {
  source = "../../modules/runtime-identity"

  project_id   = var.project_id
  account_id   = "${local.name_prefix}-worker"
  display_name = "${local.name_prefix} worker runtime"
  description  = "Development runtime identity for the Pub/Sub worker service."

  depends_on = [google_project_service.required]
}

module "batch_identity" {
  source = "../../modules/runtime-identity"

  project_id   = var.project_id
  account_id   = "${local.name_prefix}-batch"
  display_name = "${local.name_prefix} batch runtime"
  description  = "Development runtime identity for the finite Cloud Run batch job."

  depends_on = [google_project_service.required]
}

resource "google_service_account" "pubsub_push" {
  project      = var.project_id
  account_id   = "${local.name_prefix}-push"
  display_name = "${local.name_prefix} Pub/Sub push"
  description  = "Transport identity used only by Pub/Sub authenticated push delivery."

  depends_on = [google_project_service.required]
}

resource "google_service_account" "scheduler" {
  project      = var.project_id
  account_id   = "${local.name_prefix}-scheduler"
  display_name = "${local.name_prefix} scheduler"
  description  = "Trigger identity used only by Cloud Scheduler to execute the batch job."

  depends_on = [google_project_service.required]
}
