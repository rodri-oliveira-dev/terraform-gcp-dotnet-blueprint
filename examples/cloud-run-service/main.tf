module "service" {
  source = "../../modules/cloud-run-service"

  project_id      = var.project_id
  name            = var.service_name
  location        = var.location
  container_image = var.container_image
  service_account = var.service_account

  environment_variables = {
    ASPNETCORE_ENVIRONMENT = "Production"
  }

  labels = {
    component  = "api"
    managed-by = "terraform"
  }
}
