output "id" {
  description = "Fully qualified Memorystore for Redis resource ID."
  value       = google_redis_instance.this.id
}

output "name" {
  description = "Redis instance name."
  value       = google_redis_instance.this.name
}

output "host" {
  description = "Private Redis endpoint host or IP address."
  value       = google_redis_instance.this.host
}

output "port" {
  description = "Redis endpoint port."
  value       = google_redis_instance.this.port
}

output "region" {
  description = "Redis instance region."
  value       = google_redis_instance.this.region
}

output "tier" {
  description = "Configured Memorystore service tier."
  value       = google_redis_instance.this.tier
}

output "redis_version" {
  description = "Configured Redis engine version."
  value       = google_redis_instance.this.redis_version
}

output "authorized_network" {
  description = "Fully qualified VPC network authorized for the Redis instance."
  value       = google_redis_instance.this.authorized_network
}

output "connection" {
  description = "Non-secret connection metadata for workload composition. AUTH strings and CA certificate payloads are intentionally excluded."
  value = {
    host          = google_redis_instance.this.host
    port          = google_redis_instance.this.port
    tls_enabled   = var.transit_encryption_mode == "SERVER_AUTHENTICATION"
    auth_required = var.auth_enabled
  }
}
