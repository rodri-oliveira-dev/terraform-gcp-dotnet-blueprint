locals {
  required_services = toset([
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
  ])

  github_attribute_condition = join(" && ", [
    "assertion.repository_owner_id == \"${var.github_owner_id}\"",
    "assertion.repository_id == \"${var.github_repository_id}\"",
    "assertion.ref == \"${var.github_ref}\"",
  ])
}

resource "google_project_service" "required" {
  for_each = local.required_services

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = var.workload_identity_pool_id
  display_name              = "GitHub Actions"
  description               = "Federated identities for GitHub Actions without service account keys."

  depends_on = [google_project_service.required]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = var.workload_identity_provider_id
  display_name                       = "GitHub OIDC"
  description                        = "OIDC trust restricted to the configured immutable GitHub owner and repository IDs and Git ref."

  attribute_mapping = {
    "google.subject"                = "assertion.sub"
    "attribute.repository_id"       = "assertion.repository_id"
    "attribute.repository_owner_id" = "assertion.repository_owner_id"
    "attribute.ref"                 = "assertion.ref"
    "attribute.workflow_ref"        = "assertion.workflow_ref"
  }

  attribute_condition = local.github_attribute_condition

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "deployment" {
  project      = var.project_id
  account_id   = var.deployment_service_account_id
  display_name = "GitHub Actions Terraform deployer"
  description  = "Dedicated service account impersonated by trusted GitHub Actions workloads through Workload Identity Federation."

  depends_on = [google_project_service.required]
}

resource "google_service_account_iam_member" "github_workload_identity_user" {
  service_account_id = google_service_account.deployment.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository_id/${var.github_repository_id}"
}

resource "google_project_iam_member" "deployment" {
  for_each = var.deployment_project_roles

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.deployment.email}"
}
