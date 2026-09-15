resource "terraform_data" "workload_activation_lock" {
  count = var.enable_workloads ? 1 : 0

  input = {
    environment = local.environment
    activated   = true
  }

  lifecycle {
    prevent_destroy = true
  }
}
