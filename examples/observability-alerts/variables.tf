variable "project_id" {
  type        = string
  description = "Google Cloud project ID containing the example alert targets."
}

variable "location" {
  type        = string
  description = "Google Cloud region containing the example Cloud Run and Redis resources."
  default     = "us-central1"
}

variable "notification_channels" {
  type        = set(string)
  description = "Existing Cloud Monitoring notification channel resource names."
  default     = []
}
