mock_provider "google" {}

variables {
  project_id                        = "example-project"
  network_name                      = "blueprint-vpc"
  subnet_name                       = "blueprint-us-central1"
  subnet_region                     = "us-central1"
  subnet_ip_cidr_range              = "10.20.0.0/24"
  private_service_access_range_name = "blueprint-managed-services"
  private_service_access_cidr       = "10.30.0.0/16"
}

run "reject_invalid_network_name" {
  command = plan

  variables {
    network_name = "Blueprint_VPC"
  }

  expect_failures = [
    var.network_name,
  ]
}

run "reject_invalid_routing_mode" {
  command = plan

  variables {
    routing_mode = "LOCAL"
  }

  expect_failures = [
    var.routing_mode,
  ]
}

run "reject_mtu_below_platform_minimum" {
  command = plan

  variables {
    mtu = 1299
  }

  expect_failures = [
    var.mtu,
  ]
}

run "reject_ipv6_workload_subnet" {
  command = plan

  variables {
    subnet_ip_cidr_range = "fd00::/64"
  }

  expect_failures = [
    var.subnet_ip_cidr_range,
  ]
}

run "reject_workload_subnet_smaller_than_platform_minimum" {
  command = plan

  variables {
    subnet_ip_cidr_range = "10.20.0.0/30"
  }

  expect_failures = [
    var.subnet_ip_cidr_range,
  ]
}

run "reject_noncanonical_workload_subnet" {
  command = plan

  variables {
    subnet_ip_cidr_range = "10.20.0.7/24"
  }

  expect_failures = [
    var.subnet_ip_cidr_range,
  ]
}

run "reject_ipv6_private_service_access_range" {
  command = plan

  variables {
    private_service_access_cidr = "fd00::/64"
  }

  expect_failures = [
    var.private_service_access_cidr,
  ]
}

run "reject_private_service_access_range_smaller_than_memorystore_guidance" {
  command = plan

  variables {
    private_service_access_cidr = "10.30.0.0/25"
  }

  expect_failures = [
    var.private_service_access_cidr,
  ]
}

run "reject_noncanonical_private_service_access_range" {
  command = plan

  variables {
    private_service_access_cidr = "10.30.1.9/16"
  }

  expect_failures = [
    var.private_service_access_cidr,
  ]
}

run "reject_unsafe_service_networking_deletion_policy" {
  command = plan

  variables {
    private_service_access_deletion_policy = "ABANDON"
  }

  expect_failures = [
    var.private_service_access_deletion_policy,
  ]
}
