variable "project_id" {
  type        = string
  description = "Google Cloud project ID used by the isolated example."
}

variable "region" {
  type        = string
  description = "Google Cloud region used by the example."
  default     = "us-central1"
}
