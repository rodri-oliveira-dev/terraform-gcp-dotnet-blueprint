resource "google_service_account" "this" {
  project      = var.project_id
  account_id   = var.account_id
  display_name = coalesce(var.display_name, var.account_id)
  description  = var.description
  disabled     = var.disabled
}
