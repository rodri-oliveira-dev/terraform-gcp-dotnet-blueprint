module "network" {
  source = "../../modules/vpc-network"

  project_id   = var.project_id
  network_name = "blueprint-vpc"

  subnet_name          = "blueprint-${var.region}"
  subnet_region        = var.region
  subnet_ip_cidr_range = "10.20.0.0/24"

  private_service_access_range_name = "blueprint-managed-services"
  private_service_access_cidr       = "10.30.0.0/16"
}
