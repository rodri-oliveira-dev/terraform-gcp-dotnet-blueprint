variable "project_id" {
  type        = string
  description = "Google Cloud project ID where the runtime service account is created."

  validation {
    condition     = trimspace(var.project_id) != ""
    error_message = "project_id must not be empty."
  }
}

variable "account_id" {
  type        = string
  description = "Service account ID used to build the workload runtime identity."

  validation {
    condition = (
      length(var.account_id) >= 6 &&
      length(var.account_id) <= 30 &&
      can(regex("^[a-z]([-a-z0-9]*[a-z0-9])$", var.account_id))
    )
    error_message = "account_id must be 6-30 characters, start with a lowercase letter, contain only lowercase letters, digits or hyphens, and end with a lowercase letter or digit."
  }
}

variable "display_name" {
  type        = string
  description = "Optional human-readable display name. Defaults to account_id."
  default     = null
  nullable    = true

  validation {
    condition     = var.display_name == null || (trimspace(var.display_name) != "" && length(var.display_name) <= 100)
    error_message = "display_name must be null or a non-empty string of at most 100 characters."
  }
}

variable "description" {
  type        = string
  description = "Optional description of the workload boundary represented by this runtime identity."
  default     = null
  nullable    = true

  validation {
    condition     = var.description == null || length(var.description) <= 256
    error_message = "description must be 256 characters or fewer."
  }
}

variable "disabled" {
  type        = bool
  description = "Whether the service account should be disabled. Runtime identities are enabled by default."
  default     = false
}
