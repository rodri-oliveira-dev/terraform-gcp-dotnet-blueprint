output "bucket_name" {
  description = "Name of the Cloud Storage bucket used for Terraform remote state."
  value       = google_storage_bucket.terraform_state.name
}

output "bucket_url" {
  description = "Cloud Storage URL of the Terraform state bucket."
  value       = google_storage_bucket.terraform_state.url
}

output "bucket_location" {
  description = "Location of the Terraform state bucket."
  value       = google_storage_bucket.terraform_state.location
}
