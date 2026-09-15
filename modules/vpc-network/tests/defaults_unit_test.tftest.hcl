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

run "uses_private_networking_defaults" {
  command = plan

  assert {
    condition     = google_compute_network.this.auto_create_subnetworks == false
    error_message = "The VPC must use custom subnet mode."
  }

  assert {
    condition     = google_compute_network.this.routing_mode == "REGIONAL"
    error_message = "The default dynamic routing mode must remain REGIONAL."
  }

  assert {
    condition     = google_compute_network.this.mtu == 1460
    error_message = "The network must use the Google Cloud default MTU unless explicitly overridden."
  }

  assert {
    condition     = google_compute_subnetwork.this.private_ip_google_access
    error_message = "Private Google Access must be enabled on the workload subnet by default."
  }

  assert {
    condition     = google_compute_subnetwork.this.stack_type == "IPV4_ONLY"
    error_message = "The initial network contract must remain IPv4-only."
  }
}

run "creates_private_service_access_foundation" {
  command = plan

  assert {
    condition = (
      google_compute_global_address.private_service_access.purpose == "VPC_PEERING" &&
      google_compute_global_address.private_service_access.address_type == "INTERNAL" &&
      google_compute_global_address.private_service_access.address == "10.30.0.0" &&
      google_compute_global_address.private_service_access.prefix_length == 16
    )
    error_message = "Private Service Access must reserve the configured internal VPC peering CIDR."
  }

  assert {
    condition     = google_service_networking_connection.private_service_access.service == "servicenetworking.googleapis.com"
    error_message = "Private Service Access must use the Service Networking producer service."
  }

  assert {
    condition     = google_service_networking_connection.private_service_access.deletion_policy == "PREVENT"
    error_message = "The Service Networking connection must be protected from accidental deletion by default."
  }

  assert {
    condition = (
      output.direct_vpc.network == "blueprint-vpc" &&
      output.direct_vpc.subnetwork == "blueprint-us-central1"
    )
    error_message = "The Direct VPC output must expose stable network and subnet names for workload composition."
  }
}
