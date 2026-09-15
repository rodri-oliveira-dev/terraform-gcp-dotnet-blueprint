variable "project_id" {
  type        = string
  description = "Google Cloud project ID used by the production environment."

  validation {
    condition     = trimspace(var.project_id) != ""
    error_message = "project_id must not be empty."
  }
}

variable "region" {
  type        = string
  description = "Primary Google Cloud region for the production environment."
  default     = "us-central1"

  validation {
    condition     = trimspace(var.region) != ""
    error_message = "region must not be empty."
  }
}

variable "application_name" {
  type        = string
  description = "Short lowercase application prefix used to build stable production resource names."
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
  description = "Container image URI for the production .NET API. The image is only deployed when enable_workloads is true."

  validation {
    condition     = trimspace(var.api_image) != ""
    error_message = "api_image must not be empty."
  }
}

variable "worker_image" {
  type        = string
  description = "Container image URI for the production Pub/Sub worker service. The image is only deployed when enable_workloads is true."

  validation {
    condition     = trimspace(var.worker_image) != ""
    error_message = "worker_image must not be empty."
  }
}

variable "batch_image" {
  type        = string
  description = "Container image URI for the production Cloud Run Job. The image is only deployed when enable_workloads is true."

  validation {
    condition     = trimspace(var.batch_image) != ""
    error_message = "batch_image must not be empty."
  }
}

variable "enable_workloads" {
  type        = bool
  description = "Whether production request-serving services, Pub/Sub delivery, the batch job, and its scheduler are created. Keep false during the foundation/secret bootstrap phase."
  default     = false
}

variable "subnet_ip_cidr_range" {
  type        = string
  description = "Primary IPv4 CIDR for the production workload subnet."
  default     = "10.60.0.0/24"
}

variable "private_service_access_cidr" {
  type        = string
  description = "IPv4 CIDR reserved for production Private Service Access consumers such as Memorystore."
  default     = "10.70.0.0/16"
}

variable "redis_memory_size_gb" {
  type        = number
  description = "Production Memorystore capacity in GiB."
  default     = 5

  validation {
    condition     = var.redis_memory_size_gb >= 1 && var.redis_memory_size_gb <= 300 && floor(var.redis_memory_size_gb) == var.redis_memory_size_gb
    error_message = "redis_memory_size_gb must be an integer from 1 through 300."
  }
}

variable "scheduler_schedule" {
  type        = string
  description = "Cron schedule for the production batch job."
  default     = "0 2 * * *"

  validation {
    condition     = trimspace(var.scheduler_schedule) != ""
    error_message = "scheduler_schedule must not be empty."
  }
}

variable "scheduler_time_zone" {
  type        = string
  description = "IANA time zone used by the production Cloud Scheduler job."
  default     = "America/Sao_Paulo"

  validation {
    condition     = trimspace(var.scheduler_time_zone) != ""
    error_message = "scheduler_time_zone must not be empty."
  }
}

variable "labels" {
  type        = map(string)
  description = "Additional labels merged into the standard production labels."
  default     = {}
}
