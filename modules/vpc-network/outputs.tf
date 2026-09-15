output "network_id" {
  description = "Fully qualified VPC network resource ID."
  value       = google_compute_network.this.id
}

output "network_name" {
  description = "VPC network name suitable for Direct VPC egress configuration."
  value       = google_compute_network.this.name
}

output "network_self_link" {
  description = "VPC network self link."
  value       = google_compute_network.this.self_link
}

output "subnet_id" {
  description = "Fully qualified workload subnet resource ID."
  value       = google_compute_subnetwork.this.id
}

output "subnet_name" {
  description = "Workload subnet name suitable for Direct VPC egress configuration."
  value       = google_compute_subnetwork.this.name
}

output "subnet_region" {
  description = "Region containing the workload subnet."
  value       = google_compute_subnetwork.this.region
}

output "subnet_ip_cidr_range" {
  description = "Primary IPv4 CIDR range assigned to the workload subnet."
  value       = google_compute_subnetwork.this.ip_cidr_range
}

output "direct_vpc" {
  description = "Network/subnetwork names intended for composition with Cloud Run Direct VPC egress."
  value = {
    network    = google_compute_network.this.name
    subnetwork = google_compute_subnetwork.this.name
  }
}

output "private_service_access_range_name" {
  description = "Allocated VPC peering range name for Private Service Access consumers such as Memorystore."
  value       = google_compute_global_address.private_service_access.name
}

output "private_service_access_cidr" {
  description = "IPv4 CIDR block reserved for Private Service Access."
  value       = var.private_service_access_cidr
}

output "private_service_access_peering" {
  description = "Service Networking VPC peering name created for Private Service Access."
  value       = google_service_networking_connection.private_service_access.peering
}
