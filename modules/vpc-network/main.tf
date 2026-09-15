locals {
  private_service_access_address       = try(cidrhost(var.private_service_access_cidr, 0), null)
  private_service_access_prefix_length = try(tonumber(split("/", var.private_service_access_cidr)[1]), null)

  subnet_range_start = try(sum([
    for index, octet in split(".", cidrhost(var.subnet_ip_cidr_range, 0)) :
    tonumber(octet) * [16777216, 65536, 256, 1][index]
  ]), -1)
  subnet_range_end = try(sum([
    for index, octet in split(".", cidrhost(var.subnet_ip_cidr_range, -1)) :
    tonumber(octet) * [16777216, 65536, 256, 1][index]
  ]), -1)
  private_service_access_range_start = try(sum([
    for index, octet in split(".", cidrhost(var.private_service_access_cidr, 0)) :
    tonumber(octet) * [16777216, 65536, 256, 1][index]
  ]), -1)
  private_service_access_range_end = try(sum([
    for index, octet in split(".", cidrhost(var.private_service_access_cidr, -1)) :
    tonumber(octet) * [16777216, 65536, 256, 1][index]
  ]), -1)

  network_ranges_do_not_overlap = (
    local.subnet_range_start < 0 ||
    local.private_service_access_range_start < 0 ||
    local.subnet_range_end < local.private_service_access_range_start ||
    local.private_service_access_range_end < local.subnet_range_start
  )
}

resource "google_compute_network" "this" {
  project                 = var.project_id
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode            = var.routing_mode
  mtu                     = var.mtu
}

resource "google_compute_subnetwork" "this" {
  project                  = var.project_id
  name                     = var.subnet_name
  region                   = var.subnet_region
  network                  = google_compute_network.this.id
  ip_cidr_range            = var.subnet_ip_cidr_range
  private_ip_google_access = var.private_ip_google_access
  stack_type               = "IPV4_ONLY"
}

resource "google_compute_global_address" "private_service_access" {
  project       = var.project_id
  name          = var.private_service_access_range_name
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = local.private_service_access_address
  prefix_length = local.private_service_access_prefix_length
  network       = google_compute_network.this.id

  lifecycle {
    precondition {
      condition     = local.network_ranges_do_not_overlap
      error_message = "subnet_ip_cidr_range and private_service_access_cidr must not overlap. Choose distinct address ranges for the workload subnet and Private Service Access allocation."
    }
  }
}

resource "google_service_networking_connection" "private_service_access" {
  network                 = google_compute_network.this.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_access.name]
  deletion_policy         = var.private_service_access_deletion_policy
}
