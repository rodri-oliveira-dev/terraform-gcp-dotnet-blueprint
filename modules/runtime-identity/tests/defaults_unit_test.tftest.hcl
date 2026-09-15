mock_provider "google" {}

variables {
  project_id = "example-project"
  account_id = "orders-api"
}

run "creates_enabled_workload_identity_by_default" {
  command = plan

  assert {
    condition     = google_service_account.this.account_id == "orders-api"
    error_message = "The runtime identity must preserve the requested account_id."
  }

  assert {
    condition     = google_service_account.this.display_name == "orders-api"
    error_message = "display_name must default to account_id."
  }

  assert {
    condition     = google_service_account.this.disabled == false
    error_message = "Runtime identities must be enabled by default."
  }
}

run "accepts_explicit_identity_metadata" {
  command = plan

  variables {
    display_name = "Orders API runtime"
    description  = "Runtime identity used only by the orders API."
  }

  assert {
    condition     = google_service_account.this.display_name == "Orders API runtime"
    error_message = "The configured display_name must be forwarded to the service account."
  }
}
