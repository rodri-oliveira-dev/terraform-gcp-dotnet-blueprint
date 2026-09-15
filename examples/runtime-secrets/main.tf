module "api_identity" {
  source = "../../modules/runtime-identity"

  project_id   = var.project_id
  account_id   = "orders-api"
  display_name = "Orders API runtime"
  description  = "Runtime identity used only by the request-serving orders API."
}

module "worker_identity" {
  source = "../../modules/runtime-identity"

  project_id   = var.project_id
  account_id   = "orders-worker"
  display_name = "Orders worker runtime"
  description  = "Runtime identity used only by the asynchronous orders worker."
}

module "api_database_secret" {
  source = "../../modules/secret-manager"

  project_id = var.project_id
  secret_id  = "orders-database-url"
  labels     = var.labels

  accessor_service_accounts = {
    api_runtime = module.api_identity.email
  }
}

module "worker_webhook_secret" {
  source = "../../modules/secret-manager"

  project_id = var.project_id
  secret_id  = "orders-webhook-key"
  labels     = var.labels

  accessor_service_accounts = {
    worker_runtime = module.worker_identity.email
  }
}

locals {
  api_secret_environment_variables = {
    DATABASE_URL = module.api_database_secret.secret_reference
  }

  worker_secret_environment_variables = {
    WEBHOOK_KEY = module.worker_webhook_secret.secret_reference
  }
}
