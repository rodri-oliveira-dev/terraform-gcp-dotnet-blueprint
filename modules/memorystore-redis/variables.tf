variable "project_id" {
  type        = string
  description = "Google Cloud project ID where the Memorystore for Redis instance is created."

  validation {
    condition     = trimspace(var.project_id) != ""
    error_message = "project_id must not be empty."
  }
}

variable "name" {
  type        = string
  description = "Memorystore for Redis instance ID."

  validation {
    condition = (
      length(var.name) >= 1 &&
      length(var.name) <= 40 &&
      can(regex("^[a-z]([-a-z0-9]*[a-z0-9])?$", var.name))
    )
    error_message = "name must be 1-40 characters, start with a lowercase letter, contain only lowercase letters, digits, or hyphens, and end with a lowercase letter or digit."
  }
}

variable "region" {
  type        = string
  description = "Google Cloud region for the Redis instance."

  validation {
    condition     = trimspace(var.region) != ""
    error_message = "region must not be empty."
  }
}

variable "display_name" {
  type        = string
  description = "Optional human-readable display name for the Redis instance."
  default     = null
  nullable    = true

  validation {
    condition     = var.display_name == null || trimspace(var.display_name) != ""
    error_message = "display_name must be null or a non-empty string."
  }
}

variable "authorized_network" {
  type        = string
  description = "Fully qualified VPC network resource ID used by Memorystore. The module never falls back to the default network."

  validation {
    condition     = can(regex("^projects/[^/]+/global/networks/[^/]+$", var.authorized_network))
    error_message = "authorized_network must use the fully qualified format projects/PROJECT/global/networks/NETWORK."
  }
}

variable "memory_size_gb" {
  type        = number
  description = "Redis memory capacity in GiB."
  default     = 1

  validation {
    condition = (
      var.memory_size_gb >= 1 &&
      var.memory_size_gb <= 300 &&
      floor(var.memory_size_gb) == var.memory_size_gb
    )
    error_message = "memory_size_gb must be an integer from 1 through 300."
  }
}

variable "tier" {
  type        = string
  description = "Memorystore service tier. STANDARD_HA is the production-oriented default; BASIC is available for explicitly lower-cost environments."
  default     = "STANDARD_HA"

  validation {
    condition     = contains(["BASIC", "STANDARD_HA"], var.tier)
    error_message = "tier must be BASIC or STANDARD_HA."
  }
}

variable "redis_version" {
  type        = string
  description = "Redis engine version. The module intentionally supports modern Redis 6/7 versions only."
  default     = "REDIS_7_2"

  validation {
    condition     = contains(["REDIS_6_X", "REDIS_7_0", "REDIS_7_2"], var.redis_version)
    error_message = "redis_version must be REDIS_6_X, REDIS_7_0, or REDIS_7_2."
  }
}

variable "auth_enabled" {
  type        = bool
  description = "Whether Redis AUTH is enabled. Secure default is true."
  default     = true
}

variable "transit_encryption_mode" {
  type        = string
  description = "Redis TLS mode. SERVER_AUTHENTICATION encrypts client/server traffic and is the secure default."
  default     = "SERVER_AUTHENTICATION"

  validation {
    condition     = contains(["SERVER_AUTHENTICATION", "DISABLED"], var.transit_encryption_mode)
    error_message = "transit_encryption_mode must be SERVER_AUTHENTICATION or DISABLED."
  }
}

variable "location_id" {
  type        = string
  description = "Optional primary zone. When omitted, Google Cloud selects a zone."
  default     = null
  nullable    = true

  validation {
    condition     = var.location_id == null || trimspace(var.location_id) != ""
    error_message = "location_id must be null or a non-empty zone identifier."
  }
}

variable "alternative_location_id" {
  type        = string
  description = "Optional secondary zone for STANDARD_HA. It must differ from location_id when both are provided."
  default     = null
  nullable    = true

  validation {
    condition     = var.alternative_location_id == null || trimspace(var.alternative_location_id) != ""
    error_message = "alternative_location_id must be null or a non-empty zone identifier."
  }
}

variable "redis_configs" {
  type        = map(string)
  description = "Optional Redis configuration parameters supported by Memorystore."
  default     = {}
}

variable "labels" {
  type        = map(string)
  description = "Labels applied to the Redis instance."
  default     = {}
}

variable "deletion_policy" {
  type        = string
  description = "Terraform deletion policy for the Redis instance. PREVENT is the safe default; DELETE is intended only for explicitly disposable environments."
  default     = "PREVENT"

  validation {
    condition     = contains(["PREVENT", "DELETE"], var.deletion_policy)
    error_message = "deletion_policy must be PREVENT or DELETE."
  }
}
