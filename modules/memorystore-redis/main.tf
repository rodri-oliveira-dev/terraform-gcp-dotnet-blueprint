resource "google_redis_instance" "this" {
  project       = var.project_id
  name          = var.name
  region        = var.region
  display_name  = var.display_name
  memory_size_gb = var.memory_size_gb
  tier          = var.tier

  authorized_network = var.authorized_network
  connect_mode       = "PRIVATE_SERVICE_ACCESS"

  redis_version            = var.redis_version
  auth_enabled             = var.auth_enabled
  transit_encryption_mode  = var.transit_encryption_mode
  location_id              = var.location_id
  alternative_location_id  = var.alternative_location_id
  redis_configs             = var.redis_configs
  labels                    = var.labels
  deletion_policy           = var.deletion_policy

  lifecycle {
    precondition {
      condition     = var.tier == "STANDARD_HA" || var.alternative_location_id == null
      error_message = "alternative_location_id is only valid when tier is STANDARD_HA."
    }

    precondition {
      condition = (
        var.location_id == null ||
        var.alternative_location_id == null ||
        var.location_id != var.alternative_location_id
      )
      error_message = "location_id and alternative_location_id must identify different zones."
    }
  }
}
