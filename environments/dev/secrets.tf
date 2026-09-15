module "api_config_secret" {
  source = "../../modules/secret-manager"

  project_id = var.project_id
  secret_id  = "${local.name_prefix}-api-config"
  labels     = merge(local.common_labels, { component = "api" })

  accessor_service_accounts = {
    api_runtime = module.api_identity.email
  }

  depends_on = [google_project_service.required]
}

module "worker_config_secret" {
  source = "../../modules/secret-manager"

  project_id = var.project_id
  secret_id  = "${local.name_prefix}-worker-config"
  labels     = merge(local.common_labels, { component = "worker" })

  accessor_service_accounts = {
    worker_runtime = module.worker_identity.email
  }

  depends_on = [google_project_service.required]
}

module "batch_config_secret" {
  source = "../../modules/secret-manager"

  project_id = var.project_id
  secret_id  = "${local.name_prefix}-batch-config"
  labels     = merge(local.common_labels, { component = "batch" })

  accessor_service_accounts = {
    batch_runtime = module.batch_identity.email
  }

  depends_on = [google_project_service.required]
}

module "redis_auth_secret" {
  source = "../../modules/secret-manager"

  project_id = var.project_id
  secret_id  = "${local.name_prefix}-redis-auth"
  labels     = merge(local.common_labels, { component = "cache" })

  accessor_service_accounts = {
    api_runtime    = module.api_identity.email
    worker_runtime = module.worker_identity.email
    batch_runtime  = module.batch_identity.email
  }

  depends_on = [google_project_service.required]
}

module "redis_ca_secret" {
  source = "../../modules/secret-manager"

  project_id = var.project_id
  secret_id  = "${local.name_prefix}-redis-ca"
  labels     = merge(local.common_labels, { component = "cache" })

  accessor_service_accounts = {
    api_runtime    = module.api_identity.email
    worker_runtime = module.worker_identity.email
    batch_runtime  = module.batch_identity.email
  }

  depends_on = [google_project_service.required]
}
