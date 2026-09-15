variable "project_id" {
  type        = string
  description = "Google Cloud project ID used by the example."

  validation {
    condition     = trimspace(var.project_id) != ""
    error_message = "project_id must not be empty."
  }
}

variable "location" {
  type        = string
  description = "Google Cloud region for the Cloud Run worker service."
  default     = "us-central1"

  validation {
    condition     = trimspace(var.location) != ""
    error_message = "location must not be empty."
  }
}

variable "worker_image" {
  type        = string
  description = "Container image URI for the request-serving .NET worker."

  validation {
    condition     = trimspace(var.worker_image) != ""
    error_message = "worker_image must not be empty."
  }
}

variable "worker_runtime_service_account" {
  type        = string
  description = "Existing service account attached to the Cloud Run worker revision."

  validation {
    condition     = endswith(var.worker_runtime_service_account, ".iam.gserviceaccount.com")
    error_message = "worker_runtime_service_account must be a Google service account email."
  }
}

variable "push_service_account" {
  type        = string
  description = "Existing same-project service account used by Pub/Sub to authenticate push requests to Cloud Run."

  validation {
    condition = (
      endswith(var.push_service_account, ".iam.gserviceaccount.com") &&
      endswith(var.push_service_account, "@${var.project_id}.iam.gserviceaccount.com") &&
      var.push_service_account != var.worker_runtime_service_account
    )
    error_message = "push_service_account must be a Google service account in project_id and must be different from worker_runtime_service_account so transport and runtime identities remain independently scoped."
  }
}
