output "redis_connection" {
  description = "Non-secret Redis connection metadata."
  value       = module.cache.connection
}

output "redis_tier" {
  description = "Configured Redis service tier."
  value       = module.cache.tier
}

output "direct_vpc" {
  description = "Network/subnet names that Cloud Run workloads can consume for Direct VPC egress."
  value       = module.network.direct_vpc
}
