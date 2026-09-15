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

resource "google_cloud_run_v2_job" "this" {
  project             = var.project_id
  name                = var.name
  location            = var.location
  deletion_protection = var.deletion_protection
  labels              = var.labels

  template {
    task_count  = var.task_count
    parallelism = var.parallelism

    template {
      service_account = var.service_account
      max_retries     = var.max_retries
      timeout         = var.task_timeout

      dynamic "vpc_access" {
        for_each = var.direct_vpc == null ? [] : [var.direct_vpc]

        content {
          egress = vpc_access.value.egress

          network_interfaces {
            network    = vpc_access.value.network
            subnetwork = vpc_access.value.subnetwork
            tags       = sort(tolist(vpc_access.value.tags))
          }
        }
      }

      containers {
        image = var.container_image

        resources {
          limits = {
            cpu    = var.resources.cpu
            memory = var.resources.memory
          }
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
