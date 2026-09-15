mock_provider "google" {}

variables {
  project_id         = "example-project"
  name               = "orders-cache"
  region             = "us-central1"
  authorized_network = "projects/example-project/global/networks/blueprint-vpc"
}

run "reject_invalid_instance_name" {
  command = plan

  variables {
    name = "Orders_Cache"
  }

  expect_failures = [
    var.name,
  ]
}

run "reject_unqualified_authorized_network" {
  command = plan

  variables {
    authorized_network = "default"
  }

  expect_failures = [
    var.authorized_network,
  ]
}

run "reject_memory_below_service_minimum" {
  command = plan

  variables {
    memory_size_gb = 0
  }

  expect_failures = [
    var.memory_size_gb,
  ]
}

run "reject_memory_above_service_maximum" {
  command = plan

  variables {
    memory_size_gb = 301
  }

  expect_failures = [
    var.memory_size_gb,
  ]
}

run "reject_invalid_tier" {
  command = plan

  variables {
    tier = "PREMIUM"
  }

  expect_failures = [
    var.tier,
  ]
}

run "reject_legacy_redis_version" {
  command = plan

  variables {
    redis_version = "REDIS_5_0"
  }

  expect_failures = [
    var.redis_version,
  ]
}

run "reject_invalid_transit_encryption_mode" {
  command = plan

  variables {
    transit_encryption_mode = "TLS_OPTIONAL"
  }

  expect_failures = [
    var.transit_encryption_mode,
  ]
}

run "reject_alternative_zone_on_basic_tier" {
  command = plan

  variables {
    tier                    = "BASIC"
    alternative_location_id = "us-central1-b"
  }

  expect_failures = [
    google_redis_instance.this,
  ]
}

run "reject_same_ha_zones" {
  command = plan

  variables {
    location_id             = "us-central1-a"
    alternative_location_id = "us-central1-a"
  }

  expect_failures = [
    google_redis_instance.this,
  ]
}

run "reject_unsafe_deletion_policy" {
  command = plan

  variables {
    deletion_policy = "ABANDON"
  }

  expect_failures = [
    var.deletion_policy,
  ]
}
