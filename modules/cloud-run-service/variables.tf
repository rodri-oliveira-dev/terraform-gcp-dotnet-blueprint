variable "project_id" {
  type        = string
  description = "Google Cloud project ID where the Cloud Run service is created."

  validation {
    condition     = trimspace(var.project_id) != ""
    error_message = "project_id must not be empty."
  }
}

variable "name" {
  type        = string
  description = "Cloud Run service name."

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
  description = "Google Cloud region for the Cloud Run service."

  validation {
    condition     = trimspace(var.location) != ""
    error_message = "location must not be empty."
  }
}

variable "description" {
  type        = string
  description = "Optional human-readable Cloud Run service description."
  default     = null
  nullable    = true

  validation {
    condition     = var.description == null || length(var.description) <= 512
    error_message = "description must be 512 characters or fewer when provided."
  }
}

variable "container_image" {
  type        = string
  description = "Container image URI deployed by the Cloud Run service."

  validation {
    condition     = trimspace(var.container_image) != ""
    error_message = "container_image must not be empty."
  }
}

variable "service_account" {
  type        = string
  description = "Runtime service account email used by the Cloud Run revision. The module does not create or grant IAM roles to this identity."

  validation {
    condition = (
      trimspace(var.service_account) != "" &&
      strcontains(var.service_account, "@") &&
      endswith(var.service_account, ".iam.gserviceaccount.com")
    )
    error_message = "service_account must be a Google service account email ending in .iam.gserviceaccount.com."
  }
}

variable "container_port" {
  type        = number
  description = "Container port that receives Cloud Run requests."
  default     = 8080

  validation {
    condition     = var.container_port >= 1 && var.container_port <= 65535 && floor(var.container_port) == var.container_port
    error_message = "container_port must be an integer from 1 through 65535."
  }
}

variable "resources" {
  type = object({
    cpu               = optional(string, "1")
    memory            = optional(string, "512Mi")
    cpu_idle          = optional(bool, true)
    startup_cpu_boost = optional(bool, true)
  })
  description = "Container resource limits and CPU behavior. CPU is expressed as a positive numeric string and memory as Mi or Gi."
  default     = {}

  validation {
    condition     = can(tonumber(var.resources.cpu)) && tonumber(var.resources.cpu) > 0
    error_message = "resources.cpu must be a positive numeric string, for example \"1\" or \"2\"."
  }

  validation {
    condition     = can(regex("^[1-9][0-9]*(Mi|Gi)$", var.resources.memory))
    error_message = "resources.memory must be a positive quantity using Mi or Gi, for example \"512Mi\" or \"1Gi\"."
  }
}

variable "scaling" {
  type = object({
    min_instance_count = optional(number, 0)
    max_instance_count = optional(number, 10)
  })
  description = "Revision-level automatic scaling bounds. The default maximum intentionally caps reference-architecture cost exposure."
  default     = {}

  validation {
    condition = (
      var.scaling.min_instance_count >= 0 &&
      floor(var.scaling.min_instance_count) == var.scaling.min_instance_count &&
      var.scaling.max_instance_count >= 1 &&
      floor(var.scaling.max_instance_count) == var.scaling.max_instance_count &&
      var.scaling.min_instance_count <= var.scaling.max_instance_count
    )
    error_message = "scaling counts must be integers, min_instance_count must be at least 0, max_instance_count must be at least 1, and min must not exceed max."
  }
}

variable "max_instance_request_concurrency" {
  type        = number
  description = "Maximum concurrent requests served by each Cloud Run instance."
  default     = 80

  validation {
    condition = (
      var.max_instance_request_concurrency >= 1 &&
      var.max_instance_request_concurrency <= 1000 &&
      floor(var.max_instance_request_concurrency) == var.max_instance_request_concurrency
    )
    error_message = "max_instance_request_concurrency must be an integer from 1 through 1000."
  }
}

variable "timeout" {
  type        = string
  description = "Maximum request duration as a Cloud Run duration string, up to 3600 seconds."
  default     = "300s"

  validation {
    condition = (
      endswith(var.timeout, "s") &&
      can(tonumber(trimsuffix(var.timeout, "s"))) &&
      tonumber(trimsuffix(var.timeout, "s")) > 0 &&
      tonumber(trimsuffix(var.timeout, "s")) <= 3600
    )
    error_message = "timeout must be a positive duration ending in s and no greater than 3600 seconds, for example \"300s\"."
  }
}

variable "ingress" {
  type        = string
  description = "Cloud Run network ingress policy. IAM invocation policy remains outside this module."
  default     = "INGRESS_TRAFFIC_INTERNAL_ONLY"

  validation {
    condition = contains([
      "INGRESS_TRAFFIC_ALL",
      "INGRESS_TRAFFIC_INTERNAL_ONLY",
      "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER",
    ], var.ingress)
    error_message = "ingress must be one of INGRESS_TRAFFIC_ALL, INGRESS_TRAFFIC_INTERNAL_ONLY, or INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER."
  }
}

variable "deletion_protection" {
  type        = bool
  description = "Whether provider-level deletion protection is enabled for the Cloud Run service."
  default     = true
}

variable "environment_variables" {
  type        = map(string)
  description = "Non-secret environment variables passed directly to the container."
  default     = {}

  validation {
    condition     = alltrue([for name in keys(var.environment_variables) : can(regex("^[A-Za-z_][A-Za-z0-9_]*$", name))])
    error_message = "environment_variables keys must be valid environment variable identifiers."
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
      trimspace(config.secret) != "" &&
      trimspace(config.version) != ""
    ])
    error_message = "secret_environment_variables keys must be valid environment variable identifiers and each secret/version reference must be non-empty."
  }
}

variable "labels" {
  type        = map(string)
  description = "Labels applied to the Cloud Run service for ownership, environment, and billing metadata."
  default     = {}
}
