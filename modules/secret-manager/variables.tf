variable "project_id" {
  type        = string
  description = "Google Cloud project ID where the secret metadata is created."

  validation {
    condition     = trimspace(var.project_id) != ""
    error_message = "project_id must not be empty."
  }
}

variable "secret_id" {
  type        = string
  description = "Secret Manager secret ID. This module manages metadata only, never secret payloads."

  validation {
    condition = (
      length(var.secret_id) >= 1 &&
      length(var.secret_id) <= 255 &&
      can(regex("^[A-Za-z0-9_-]+$", var.secret_id))
    )
    error_message = "secret_id must be 1-255 characters and contain only letters, digits, hyphens, or underscores."
  }
}

variable "accessor_service_accounts" {
  type        = map(string)
  description = "Map of caller-chosen stable accessor IDs to service account emails granted roles/secretmanager.secretAccessor on this secret only. Keep map keys static even when email values come from other resources."
  default     = {}

  validation {
    condition = alltrue([
      for key, email in var.accessor_service_accounts :
      trimspace(key) != "" &&
      trimspace(email) != "" &&
      strcontains(email, "@") &&
      endswith(email, ".iam.gserviceaccount.com")
    ])
    error_message = "Every accessor key must be non-empty and every accessor value must be a Google service account email ending in .iam.gserviceaccount.com."
  }
}

variable "replication_locations" {
  type        = set(string)
  description = "Optional user-managed replication locations. Empty means automatic replication."
  default     = []

  validation {
    condition = alltrue([
      for location in var.replication_locations : trimspace(location) != ""
    ])
    error_message = "replication_locations must contain only non-empty Google Cloud location names."
  }
}

variable "reference_version" {
  type        = string
  description = "Version or alias exposed in secret_reference for Cloud Run consumers. The module does not create that version."
  default     = "latest"

  validation {
    condition     = trimspace(var.reference_version) != ""
    error_message = "reference_version must not be empty."
  }
}

variable "deletion_protection" {
  type        = bool
  description = "Whether Terraform is prevented from deleting the Secret Manager secret metadata."
  default     = true
}

variable "labels" {
  type        = map(string)
  description = "Labels applied to the Secret Manager secret."
  default     = {}
}
