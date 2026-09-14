variable "project_id" {
  description = "Google Cloud project ID that owns the Terraform state bucket."
  type        = string

  validation {
    condition     = length(trimspace(var.project_id)) > 0
    error_message = "project_id must not be empty."
  }
}

variable "bucket_name" {
  description = "Globally unique Cloud Storage bucket name used for Terraform state."
  type        = string

  validation {
    condition = (
      length(var.bucket_name) >= 3 &&
      length(var.bucket_name) <= 63 &&
      can(regex("^[a-z0-9][a-z0-9._-]*[a-z0-9]$", var.bucket_name))
    )
    error_message = "bucket_name must be 3-63 characters, use lowercase letters, numbers, dots, underscores, or hyphens, and start/end with a letter or number."
  }
}

variable "location" {
  description = "Cloud Storage location for the Terraform state bucket, for example US or southamerica-east1."
  type        = string
  default     = "US"

  validation {
    condition     = length(trimspace(var.location)) > 0
    error_message = "location must not be empty."
  }
}

variable "labels" {
  description = "Labels applied to the Terraform state bucket."
  type        = map(string)
  default = {
    managed_by = "terraform"
    purpose    = "terraform-state"
  }
}
