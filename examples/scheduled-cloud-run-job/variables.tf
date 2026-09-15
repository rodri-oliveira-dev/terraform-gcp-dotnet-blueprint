variable "project_id" {
  type        = string
  description = "Google Cloud project hosting the Cloud Run Job and Cloud Scheduler job."
}

variable "location" {
  type        = string
  description = "Region for Cloud Run and Cloud Scheduler."
  default     = "us-central1"
}

variable "container_image" {
  type        = string
  description = "Container image executed by the batch job."
}

variable "runtime_service_account" {
  type        = string
  description = "Existing service account used by the batch container at runtime."
}

variable "scheduler_service_account" {
  type        = string
  description = "Existing service account used by Cloud Scheduler to call the Cloud Run Admin API."

  validation {
    condition = (
      endswith(var.scheduler_service_account, "@${var.project_id}.iam.gserviceaccount.com")
    )
    error_message = "scheduler_service_account must belong to project_id because Cloud Scheduler OAuth service accounts must be in the same project as the scheduler job."
  }
}

variable "schedule" {
  type        = string
  description = "Cron schedule used by Cloud Scheduler."
  default     = "0 2 * * *"

  validation {
    condition     = trimspace(var.schedule) != ""
    error_message = "schedule must not be empty."
  }
}

variable "time_zone" {
  type        = string
  description = "IANA timezone used to interpret the cron schedule."
  default     = "America/Sao_Paulo"

  validation {
    condition     = trimspace(var.time_zone) != ""
    error_message = "time_zone must not be empty."
  }
}
