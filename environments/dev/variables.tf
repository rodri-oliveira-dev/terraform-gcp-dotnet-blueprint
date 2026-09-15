variable "project_id" {
  type        = string
  description = "Google Cloud project ID used by the development environment."

  validation {
    condition     = trimspace(var.project_id) != ""
    error_message = "project_id must not be empty."
  }
}

variable "region" {
  type        = string
  description = "Primary Google Cloud region for the development environment."
  default     = "us-central1"

  validation {
    condition     = trimspace(var.region) != ""
    error_message = "region must not be empty."
  }
}

variable "application_name" {
  type        = string
  description = "Short lowercase application prefix used to build stable development resource names."
  default     = "blueprint"

  validation {
    condition = (
      length(var.application_name) >= 3 &&
      length(var.application_name) <= 15 &&
      can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.application_name))
    )
    error_message = "application_name must be 3-15 characters, start with a lowercase letter, contain only lowercase letters, digits or hyphens, and end with a lowercase letter or digit."
  }
}

variable "api_image" {
  type        = string
  description = "Container image URI for the development .NET API. The image is only deployed when enable_workloads is true."

  validation {
    condition     = trimspace(var.api_image) != ""
    error_message = "api_image must not be empty."
  }
}

variable "worker_image" {
  type        = string
  description = "Container image URI for the development Pub/Sub worker service. The image is only deployed when enable_workloads is true."

  validation {
    condition     = trimspace(var.worker_image) != ""
    error_message = "worker_image must not be empty."
  }
}

variable "batch_image" {
  type        = string
  description = "Container image URI for the development Cloud Run Job. The image is only deployed when enable_workloads is true."

  validation {
    condition     = trimspace(var.batch_image) != ""
    error_message = "batch_image must not be empty."
  }
}

variable "enable_workloads" {
  type        = bool
  description = "One-way workload activation flag. Keep false during foundation/secret bootstrap, then set true to create workloads. Once applied as true in this state, changing it back to false is intentionally rejected before any workload destruction can occur."
  default     = false
}

variable "subnet_ip_cidr_range" {
  type        = string
  description = "Primary IPv4 CIDR for the development workload subnet."
  default     = "10.40.0.0/24"
}

variable "private_service_access_cidr" {
  type        = string
  description = "IPv4 CIDR reserved for Private Service Access consumers such as Memorystore."
  default     = "10.50.0.0/16"
}

variable "scheduler_schedule" {
  type        = string
  description = "Cron schedule for the development batch job."
  default     = "0 2 * * *"

  validation {
    condition     = trimspace(var.scheduler_schedule) != ""
    error_message = "scheduler_schedule must not be empty."
  }
}

variable "scheduler_time_zone" {
  type        = string
  description = "IANA time zone used by Cloud Scheduler."
  default     = "America/Sao_Paulo"

  validation {
    condition     = trimspace(var.scheduler_time_zone) != ""
    error_message = "scheduler_time_zone must not be empty."
  }
}

variable "observability_notification_channels" {
  type        = set(string)
  description = "Existing Cloud Monitoring notification channel resource names attached to development alert policies. Destinations are managed outside this root."
  default     = []

  validation {
    condition = alltrue([
      for channel in var.observability_notification_channels :
      can(regex("^projects/[^/]+/notificationChannels/[^/]+$", channel))
    ])
    error_message = "observability_notification_channels entries must use projects/PROJECT/notificationChannels/CHANNEL_ID resource names."
  }
}

variable "observability_thresholds" {
  type = object({
    cloud_run_server_error_ratio      = optional(number, 0.10)
    pubsub_oldest_unacked_age_seconds = optional(number, 600)
    redis_memory_usage_ratio          = optional(number, 0.90)
    redis_system_memory_usage_ratio   = optional(number, 0.90)
  })
  description = "Development alert thresholds. Defaults are intentionally more tolerant than production while preserving the same signal set."
  default     = {}
}

variable "labels" {
  type        = map(string)
  description = "Additional labels merged into the standard development labels."
  default     = {}
}
