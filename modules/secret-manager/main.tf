resource "google_secret_manager_secret" "this" {
  project             = var.project_id
  secret_id           = var.secret_id
  labels              = var.labels
  deletion_protection = var.deletion_protection

  replication {
    dynamic "auto" {
      for_each = length(var.replication_locations) == 0 ? [1] : []
      content {}
    }

    dynamic "user_managed" {
      for_each = length(var.replication_locations) == 0 ? [] : [1]

      content {
        dynamic "replicas" {
          for_each = var.replication_locations

          content {
            location = replicas.value
          }
        }
      }
    }
  }
}

resource "google_secret_manager_secret_iam_member" "accessor" {
  for_each = var.accessor_service_account_emails

  project   = var.project_id
  secret_id = google_secret_manager_secret.this.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${each.value}"
}
