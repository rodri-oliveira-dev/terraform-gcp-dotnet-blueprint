variable "project_id" {
  type        = string
  description = "Google Cloud project ID where alert policies are created and target metrics are emitted."

  validation {
    condition     = trimspace(var.project_id) != ""
    error_message = "project_id must not be empty."
  }
}

variable "environment" {
  type        = string
  description = "Short environment identifier used in alert display names and labels."

  validation {
    condition = (
      length(var.environment) >= 2 &&
      length(var.environment) <= 32 &&
      can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.environment))
    )
    error_message = "environment must be 2-32 lowercase characters, start with a letter, contain only letters, digits or hyphens, and end with a letter or digit."
  }
}

variable "location" {
  type        = string
  description = "Google Cloud region used to scope Cloud Run and Redis alert targets."

  validation {
    condition     = trimspace(var.location) != ""
    error_message = "location must not be empty."
  }
}

variable "cloud_run_services" {
  type        = map(string)
  description = "Map of stable semantic target IDs (for example api or worker) to Cloud Run service names."
  default     = {}

  validation {
    condition = alltrue([
      for key, name in var.cloud_run_services :
      can(regex("^[a-z][a-z0-9_-]{0,62}$", key)) &&
      length(name) >= 1 &&
      length(name) <= 49 &&
      can(regex("^[a-z]([a-z0-9-]*[a-z0-9])?$", name))
    ])
    error_message = "cloud_run_services keys must be valid lowercase label values and service names must be valid 1-49 character Cloud Run names."
  }
}

variable "cloud_run_job_name" {
  type        = string
  description = "Optional Cloud Run Job name monitored for failed executions."
  default     = null
  nullable    = true

  validation {
    condition = var.cloud_run_job_name == null || (
      length(var.cloud_run_job_name) >= 1 &&
      length(var.cloud_run_job_name) <= 49 &&
      can(regex("^[a-z]([a-z0-9-]*[a-z0-9])?$", var.cloud_run_job_name))
    )
    error_message = "cloud_run_job_name must be null or a valid 1-49 character Cloud Run Job name."
  }
}

variable "pubsub_subscription_name" {
  type        = string
  description = "Optional primary Pub/Sub subscription name monitored for stale backlog and dead-letter forwarding."
  default     = null
  nullable    = true

  validation {
    condition = var.pubsub_subscription_name == null || (
      length(var.pubsub_subscription_name) >= 3 &&
      length(var.pubsub_subscription_name) <= 255 &&
      can(regex("^[A-Za-z][A-Za-z0-9._~+%-]{2,254}$", var.pubsub_subscription_name)) &&
      !startswith(lower(var.pubsub_subscription_name), "goog")
    )
    error_message = "pubsub_subscription_name must be null or a valid Pub/Sub subscription name."
  }
}

variable "redis_instance_id" {
  type        = string
  description = "Optional Memorystore for Redis instance ID monitored for memory pressure and rejected connections."
  default     = null
  nullable    = true

  validation {
    condition = var.redis_instance_id == null || (
      length(var.redis_instance_id) >= 1 &&
      length(var.redis_instance_id) <= 40 &&
      can(regex("^[a-z]([-a-z0-9]*[a-z0-9])?$", var.redis_instance_id))
    )
    error_message = "redis_instance_id must be null or a valid 1-40 character Memorystore instance ID."
  }
}

variable "notification_channels" {
  type        = set(string)
  description = "Existing Cloud Monitoring notification channel resource names. This module never creates or configures channel destinations."
  default     = []

  validation {
    condition = alltrue([
      for channel in var.notification_channels :
      can(regex("^projects/[^/]+/notificationChannels/[^/]+$", channel))
    ])
    error_message = "notification_channels entries must use projects/PROJECT/notificationChannels/CHANNEL_ID resource names."
  }
}

variable "enabled" {
  type        = bool
  description = "Whether the alert policies managed by this module are enabled."
  default     = true
}

variable "thresholds" {
  type = object({
    cloud_run_server_error_ratio      = optional(number, 0.05)
    pubsub_oldest_unacked_age_seconds = optional(number, 300)
    redis_memory_usage_ratio          = optional(number, 0.80)
    redis_system_memory_usage_ratio   = optional(number, 0.80)
  })
  description = "Portable alert thresholds. Defaults favor actionable infrastructure signals rather than workload-specific SLO targets."
  default     = {}

  validation {
    condition = (
      var.thresholds.cloud_run_server_error_ratio > 0 &&
      var.thresholds.cloud_run_server_error_ratio <= 1
    )
    error_message = "thresholds.cloud_run_server_error_ratio must be greater than 0 and at most 1."
  }

  validation {
    condition = (
      var.thresholds.pubsub_oldest_unacked_age_seconds >= 60 &&
      var.thresholds.pubsub_oldest_unacked_age_seconds <= 86400 &&
      floor(var.thresholds.pubsub_oldest_unacked_age_seconds) == var.thresholds.pubsub_oldest_unacked_age_seconds
    )
    error_message = "thresholds.pubsub_oldest_unacked_age_seconds must be an integer from 60 through 86400 seconds."
  }

  validation {
    condition = (
      var.thresholds.redis_memory_usage_ratio > 0 &&
      var.thresholds.redis_memory_usage_ratio <= 1 &&
      var.thresholds.redis_system_memory_usage_ratio > 0 &&
      var.thresholds.redis_system_memory_usage_ratio <= 1
    )
    error_message = "Redis memory ratio thresholds must be greater than 0 and at most 1."
  }
}

variable "labels" {
  type        = map(string)
  description = "Additional Cloud Monitoring user labels merged into the module's environment and management labels."
  default     = {}

  validation {
    condition = alltrue([
      for key, value in var.labels :
      can(regex("^[a-z][a-z0-9_-]{0,62}$", key)) &&
      can(regex("^[a-z0-9_-]{0,63}$", value))
    ])
    error_message = "labels must use Cloud Monitoring-compatible lowercase keys and values."
  }
}
