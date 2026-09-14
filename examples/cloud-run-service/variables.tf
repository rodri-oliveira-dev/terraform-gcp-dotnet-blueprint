variable "project_id" {
  type        = string
  description = "Google Cloud project ID used by the example."
}

variable "location" {
  type        = string
  description = "Google Cloud region used by the example."
  default     = "us-central1"
}

variable "service_name" {
  type        = string
  description = "Cloud Run service name used by the example."
  default     = "blueprint-api"
}

variable "container_image" {
  type        = string
  description = "Container image deployed by the example."
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "service_account" {
  type        = string
  description = "Existing runtime service account email used by the example."
}
