variable "project_id" {
  type        = string
  description = "Google Cloud project ID where the Cloud Run job is created."

  validation {
    condition     = trimspace(var.project_id) != ""
    error_message = "project_id must not be empty."
  }
}

variable "name" {
  type        = string
  description = "Cloud Run job name."

  validation {
    condition = (
      length(var.name) >= 1 &&
      length(var.name) <= 49 &&
      can(regex("^[a-z][a-z0-9-]*$", var.name)) &&
      !endswith(var.name, "-")
    )
    error_message = "name must be 1-49 characters, start with a lowercase letter, contain only lowercase letters, numbers, or hyphens, and not end with a hyphen."
  }
}

variable "location" {
  type        = string
  description = "Google Cloud region for the Cloud Run job."

  validation {
    condition     = trimspace(var.location) != ""
    error_message = "location must not be empty."
  }
}

variable "container_image" {
  type        = string
  description = "Container image URI executed by the Cloud Run job."

  validation {
    condition     = trimspace(var.container_image) != ""
    error_message = "container_image must not be empty."
  }
}

variable "service_account" {
  type        = string
  description = "Runtime service account email used by Cloud Run job tasks. The module does not create or grant IAM roles to this identity."

  validation {
    condition = (
      trimspace(var.service_account) != "" &&
      strcontains(var.service_account, "@") &&
      endswith(var.service_account, ".iam.gserviceaccount.com")
    )
    error_message = "service_account must be a Google service account email ending in .iam.gserviceaccount.com."
  }
}

variable "task_count" {
  type        = number
  description = "Number of independent tasks executed by each job execution."
  default     = 1

  validation {
    condition = (
      var.task_count >= 1 &&
      var.task_count <= 10000 &&
      floor(var.task_count) == var.task_count
    )
    error_message = "task_count must be an integer from 1 through 10000."
  }
}

variable "parallelism" {
  type        = number
  description = "Maximum number of tasks allowed to execute concurrently."
  default     = 1

  validation {
    condition = (
      var.parallelism >= 1 &&
      floor(var.parallelism) == var.parallelism &&
      var.parallelism <= var.task_count
    )
    error_message = "parallelism must be a positive integer and must not exceed task_count."
  }
}

variable "max_retries" {
  type        = number
  description = "Maximum retries per failed task."
  default     = 3

  validation {
    condition = (
      var.max_retries >= 0 &&
      var.max_retries <= 10 &&
      floor(var.max_retries) == var.max_retries
    )
    error_message = "max_retries must be an integer from 0 through 10."
  }
}

variable "task_timeout" {
  type        = string
  description = "Maximum duration of one task, expressed as whole seconds. Maximum is 7 days."
  default     = "600s"

  validation {
    condition = (
      can(regex("^[1-9][0-9]*s$", var.task_timeout)) &&
      tonumber(trimsuffix(var.task_timeout, "s")) <= 604800
    )
    error_message = "task_timeout must be whole positive seconds ending in s and no greater than 604800s (7 days)."
  }
}

variable "resources" {
  type = object({
    cpu    = optional(string, "1")
    memory = optional(string, "512Mi")
  })
  description = "Container compute limits. This module intentionally supports 1, 2, or 4 whole vCPU configurations."
  default     = {}

  validation {
    condition     = contains(["1", "2", "4"], var.resources.cpu)
    error_message = "resources.cpu must be one of \"1\", \"2\", or \"4\". Higher CPU values requiring explicit Gen2 handling are outside this module's current contract."
  }

  validation {
    condition = can(regex("^[1-9][0-9]*(Mi|Gi)$", var.resources.memory)) && (
      endswith(var.resources.memory, "Gi")
      ? tonumber(trimsuffix(var.resources.memory, "Gi")) * 1024
      : tonumber(trimsuffix(var.resources.memory, "Mi"))
      ) >= 512 && (
      endswith(var.resources.memory, "Gi")
      ? tonumber(trimsuffix(var.resources.memory, "Gi")) * 1024
      : tonumber(trimsuffix(var.resources.memory, "Mi"))
    ) <= 16384
    error_message = "resources.memory must be between 512Mi and 16Gi."
  }

  validation {
    condition = (
      var.resources.cpu == "1" ? (
        endswith(var.resources.memory, "Gi")
        ? tonumber(trimsuffix(var.resources.memory, "Gi")) * 1024
        : tonumber(trimsuffix(var.resources.memory, "Mi"))
      ) <= 4096 :
      var.resources.cpu == "2" ? (
        endswith(var.resources.memory, "Gi")
        ? tonumber(trimsuffix(var.resources.memory, "Gi")) * 1024
        : tonumber(trimsuffix(var.resources.memory, "Mi"))
      ) <= 8192 :
      var.resources.cpu == "4" ? (
        (
          endswith(var.resources.memory, "Gi")
          ? tonumber(trimsuffix(var.resources.memory, "Gi")) * 1024
          : tonumber(trimsuffix(var.resources.memory, "Mi"))
        ) >= 2048 &&
        (
          endswith(var.resources.memory, "Gi")
          ? tonumber(trimsuffix(var.resources.memory, "Gi")) * 1024
          : tonumber(trimsuffix(var.resources.memory, "Mi"))
        ) <= 16384
      ) : false
    )
    error_message = "resources.memory is incompatible with resources.cpu. Supported maxima are 4Gi for 1 vCPU and 8Gi for 2 vCPU; 4 vCPU requires 2-16Gi."
  }
}

variable "environment_variables" {
  type        = map(string)
  description = "Non-secret environment variables passed directly to the job container."
  default     = {}

  validation {
    condition = alltrue([
      for name in keys(var.environment_variables) :
      can(regex("^[A-Za-z_][A-Za-z0-9_]*$", name)) &&
      !startswith(name, "CLOUD_RUN_") &&
      !startswith(name, "X_GOOGLE_")
    ])
    error_message = "environment_variables keys must be valid identifiers and must not use Cloud Run-reserved CLOUD_RUN_ or X_GOOGLE_ prefixes."
  }
}

variable "secret_environment_variables" {
  type = map(object({
    secret  = string
    version = optional(string, "latest")
  }))
  description = "Environment variables sourced from Secret Manager references. Only secret identifiers and versions are accepted; secret payloads are not inputs."
  default     = {}

  validation {
    condition = alltrue([
      for name, config in var.secret_environment_variables :
      can(regex("^[A-Za-z_][A-Za-z0-9_]*$", name)) &&
      !startswith(name, "CLOUD_RUN_") &&
      !startswith(name, "X_GOOGLE_") &&
      trimspace(config.secret) != "" &&
      trimspace(config.version) != ""
    ])
    error_message = "secret_environment_variables keys must be valid, non-reserved identifiers and each secret/version reference must be non-empty."
  }
}

variable "labels" {
  type        = map(string)
  description = "Labels applied to the Cloud Run job."
  default     = {}
}

variable "deletion_protection" {
  type        = bool
  description = "Whether provider-level deletion protection is enabled for the Cloud Run job."
  default     = true
}
