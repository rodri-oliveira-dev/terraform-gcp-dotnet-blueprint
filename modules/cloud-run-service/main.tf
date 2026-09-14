locals {
  container_environment = merge(
    {
      for name, value in var.environment_variables : name => {
        value  = value
        secret = null
      }
    },
    {
      for name, config in var.secret_environment_variables : name => {
        value  = null
        secret = config
      }
    }
  )
}

resource "google_cloud_run_v2_service" "this" {
  project             = var.project_id
  name                = var.name
  location            = var.location
  description         = var.description
  ingress             = var.ingress
  deletion_protection = var.deletion_protection
  labels              = var.labels

  template {
    service_account                  = var.service_account
    max_instance_request_concurrency = var.max_instance_request_concurrency
    timeout                          = var.timeout

    scaling {
      min_instance_count = var.scaling.min_instance_count
      max_instance_count = var.scaling.max_instance_count
    }

    containers {
      image = var.container_image

      ports {
        container_port = var.container_port
      }

      resources {
        limits = {
          cpu    = var.resources.cpu
          memory = var.resources.memory
        }
        cpu_idle          = var.resources.cpu_idle
        startup_cpu_boost = var.resources.startup_cpu_boost
      }

      dynamic "env" {
        for_each = local.container_environment

        content {
          name  = env.key
          value = env.value.secret == null ? env.value.value : null

          dynamic "value_source" {
            for_each = env.value.secret == null ? [] : [env.value.secret]

            content {
              secret_key_ref {
                secret  = value_source.value.secret
                version = value_source.value.version
              }
            }
          }
        }
      }
    }
  }

  lifecycle {
    precondition {
      condition = length(setintersection(
        toset(keys(var.environment_variables)),
        toset(keys(var.secret_environment_variables)),
      )) == 0
      error_message = "An environment variable name cannot be configured as both a literal value and a Secret Manager reference."
    }
  }
}
