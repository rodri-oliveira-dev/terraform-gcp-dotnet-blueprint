output "direct_vpc" {
  description = "Network and subnet names that can be passed directly to modules/cloud-run-service.direct_vpc or modules/cloud-run-job.direct_vpc."
  value       = module.network.direct_vpc
}

output "private_service_access_range_name" {
  description = "Allocated range name intended for managed services such as Memorystore."
  value       = module.network.private_service_access_range_name
}

output "private_service_access_peering" {
  description = "Service Networking peering created for Private Service Access."
  value       = module.network.private_service_access_peering
}
