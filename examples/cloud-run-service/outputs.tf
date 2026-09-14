output "service_name" {
  description = "Cloud Run service name created by the example."
  value       = module.service.name
}

output "service_uri" {
  description = "Cloud Run service URI created by the example."
  value       = module.service.uri
}
