mock_provider "google" {}

variables {
  project_id = "example-project"
  secret_id  = "orders-database-url"
}

run "uses_secure_metadata_defaults" {
  command = plan

  assert {
    condition     = google_secret_manager_secret.this.deletion_protection
    error_message = "Secret metadata must enable deletion protection by default."
  }

  assert {
    condition     = length(google_secret_manager_secret.this.replication[0].auto) == 1
    error_message = "Secrets must use automatic replication when no locations are provided."
  }

  assert {
    condition     = length(google_secret_manager_secret_iam_member.accessor) == 0
    error_message = "No principal should receive secret access unless explicitly configured."
  }

  assert {
    condition = (
      output.secret_reference.secret == "orders-database-url" &&
      output.secret_reference.version == "latest"
    )
    error_message = "The default secret reference must expose only the secret ID and latest alias."
  }
}

run "grants_only_explicit_secret_accessors" {
  command = plan

  variables {
    accessor_service_accounts = {
      api_runtime    = "orders-api@example-project.iam.gserviceaccount.com"
      worker_runtime = "orders-worker@example-project.iam.gserviceaccount.com"
    }
  }

  assert {
    condition     = length(google_secret_manager_secret_iam_member.accessor) == 2
    error_message = "Each explicitly configured accessor must receive one resource-scoped IAM member."
  }

  assert {
    condition     = google_secret_manager_secret_iam_member.accessor["api_runtime"].role == "roles/secretmanager.secretAccessor"
    error_message = "Accessors must receive only roles/secretmanager.secretAccessor."
  }

  assert {
    condition     = google_secret_manager_secret_iam_member.accessor["api_runtime"].member == "serviceAccount:orders-api@example-project.iam.gserviceaccount.com"
    error_message = "Stable accessor keys must map to the configured service account email value."
  }
}

run "supports_user_managed_replication" {
  command = plan

  variables {
    replication_locations = ["us-central1", "us-east1"]
  }

  assert {
    condition     = length(google_secret_manager_secret.this.replication[0].user_managed) == 1
    error_message = "Providing replication locations must select user-managed replication."
  }
}
