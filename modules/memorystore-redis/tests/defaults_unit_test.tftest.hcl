mock_provider "google" {
  override_during = plan

  mock_resource "google_redis_instance" {
    defaults = {
      host                = "10.30.0.5"
      port                = 6378
      current_location_id = "us-central1-a"
    }
  }
}

variables {
  project_id         = "example-project"
  name               = "orders-cache"
  region             = "us-central1"
  authorized_network = "projects/example-project/global/networks/blueprint-vpc"
}

run "secure_defaults" {
  command = plan

  assert {
    condition     = google_redis_instance.this.connect_mode == "PRIVATE_SERVICE_ACCESS"
    error_message = "The module must use Private Service Access rather than direct peering."
  }

  assert {
    condition     = google_redis_instance.this.authorized_network == var.authorized_network
    error_message = "The explicitly supplied VPC network must be used by Memorystore."
  }

  assert {
    condition     = google_redis_instance.this.tier == "STANDARD_HA"
    error_message = "STANDARD_HA must be the production-oriented default tier."
  }

  assert {
    condition     = google_redis_instance.this.memory_size_gb == 1
    error_message = "The default Redis capacity must be 1 GiB."
  }

  assert {
    condition     = google_redis_instance.this.redis_version == "REDIS_7_2"
    error_message = "Redis 7.2 must be the default engine version."
  }

  assert {
    condition     = google_redis_instance.this.auth_enabled
    error_message = "Redis AUTH must be enabled by default."
  }

  assert {
    condition     = google_redis_instance.this.transit_encryption_mode == "SERVER_AUTHENTICATION"
    error_message = "TLS server authentication must be enabled by default."
  }

  assert {
    condition     = google_redis_instance.this.deletion_policy == "PREVENT"
    error_message = "Redis deletion must be prevented by default."
  }

  assert {
    condition = (
      output.connection.host == "10.30.0.5" &&
      output.connection.port == 6378 &&
      output.connection.tls_enabled &&
      output.connection.auth_required
    )
    error_message = "The connection output must expose only the expected non-secret endpoint metadata."
  }
}

run "supports_basic_tier_without_weakening_transport_security" {
  command = plan

  variables {
    tier = "BASIC"
  }

  assert {
    condition = (
      google_redis_instance.this.tier == "BASIC" &&
      google_redis_instance.this.auth_enabled &&
      google_redis_instance.this.transit_encryption_mode == "SERVER_AUTHENTICATION"
    )
    error_message = "Choosing BASIC must not implicitly disable AUTH or TLS."
  }
}
