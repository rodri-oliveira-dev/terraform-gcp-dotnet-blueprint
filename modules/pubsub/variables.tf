variable "project_id" {
  type        = string
  description = "Google Cloud project ID containing the Pub/Sub resources."

  validation {
    condition     = trimspace(var.project_id) != ""
    error_message = "project_id must not be empty."
  }
}

variable "topic_name" {
  type        = string
  description = "Primary Pub/Sub topic name."

  validation {
    condition = (
      length(var.topic_name) >= 3 &&
      length(var.topic_name) <= 255 &&
      can(regex("^[A-Za-z][A-Za-z0-9._~+%-]{2,254}$", var.topic_name)) &&
      !startswith(lower(var.topic_name), "goog")
    )
    error_message = "topic_name must be 3-255 characters, start with a letter, use Pub/Sub-safe characters, and must not start with goog."
  }
}

variable "subscription_name" {
  type        = string
  description = "Primary Pub/Sub subscription name."

  validation {
    condition = (
      length(var.subscription_name) >= 3 &&
      length(var.subscription_name) <= 255 &&
      can(regex("^[A-Za-z][A-Za-z0-9._~+%-]{2,254}$", var.subscription_name)) &&
      !startswith(lower(var.subscription_name), "goog")
    )
    error_message = "subscription_name must be 3-255 characters, start with a letter, use Pub/Sub-safe characters, and must not start with goog."
  }
}

variable "ack_deadline_seconds" {
  type        = number
  description = "Initial acknowledgement deadline for delivered messages."
  default     = 60

  validation {
    condition = (
      var.ack_deadline_seconds >= 10 &&
      var.ack_deadline_seconds <= 600 &&
      floor(var.ack_deadline_seconds) == var.ack_deadline_seconds
    )
    error_message = "ack_deadline_seconds must be an integer from 10 through 600."
  }
}

variable "message_retention_seconds" {
  type        = number
  description = "How long Pub/Sub retains subscription messages, in seconds."
  default     = 604800

  validation {
    condition = (
      var.message_retention_seconds >= 600 &&
      var.message_retention_seconds <= 2678400 &&
      floor(var.message_retention_seconds) == var.message_retention_seconds
    )
    error_message = "message_retention_seconds must be an integer from 600 seconds (10 minutes) through 2678400 seconds (31 days)."
  }
}

variable "retain_acked_messages" {
  type        = bool
  description = "Whether acknowledged messages remain retained for the configured retention duration."
  default     = false
}

variable "enable_message_ordering" {
  type        = bool
  description = "Whether Pub/Sub preserves ordering for messages that use the same ordering key."
  default     = false
}

variable "filter" {
  type        = string
  description = "Optional Pub/Sub subscription filter. This module accepts printable ASCII only so the 256-character check is also a 256-byte check."
  default     = null
  nullable    = true

  validation {
    condition = (
      var.filter == null ||
      (
        trimspace(var.filter) != "" &&
        length(var.filter) <= 256 &&
        can(regex("^[ -~]+$", var.filter))
      )
    )
    error_message = "filter must be null or a non-empty printable-ASCII expression of at most 256 bytes."
  }
}

variable "retry_policy" {
  type = object({
    minimum_backoff_seconds = optional(number, 10)
    maximum_backoff_seconds = optional(number, 600)
  })
  description = "Exponential retry backoff bounds for message redelivery."
  default     = {}

  validation {
    condition = (
      var.retry_policy.minimum_backoff_seconds >= 0 &&
      var.retry_policy.minimum_backoff_seconds <= 600 &&
      var.retry_policy.maximum_backoff_seconds >= 0 &&
      var.retry_policy.maximum_backoff_seconds <= 600 &&
      var.retry_policy.minimum_backoff_seconds <= var.retry_policy.maximum_backoff_seconds
    )
    error_message = "retry backoff values must be between 0 and 600 seconds, and minimum_backoff_seconds must not exceed maximum_backoff_seconds."
  }
}

variable "dead_letter" {
  type = object({
    enabled                        = optional(bool, true)
    topic_name                     = optional(string, null)
    subscription_name              = optional(string, null)
    max_delivery_attempts          = optional(number, 10)
    create_inspection_subscription = optional(bool, true)
  })
  description = "Dead-letter topic, inspection subscription, and maximum delivery-attempt configuration."
  default     = {}

  validation {
    condition = (
      var.dead_letter.max_delivery_attempts >= 5 &&
      var.dead_letter.max_delivery_attempts <= 100 &&
      floor(var.dead_letter.max_delivery_attempts) == var.dead_letter.max_delivery_attempts
    )
    error_message = "dead_letter.max_delivery_attempts must be an integer from 5 through 100."
  }

  validation {
    condition = var.dead_letter.topic_name == null || (
      length(var.dead_letter.topic_name) >= 3 &&
      length(var.dead_letter.topic_name) <= 255 &&
      can(regex("^[A-Za-z][A-Za-z0-9._~+%-]{2,254}$", var.dead_letter.topic_name)) &&
      !startswith(lower(var.dead_letter.topic_name), "goog")
    )
    error_message = "dead_letter.topic_name must be null or a valid Pub/Sub topic name."
  }

  validation {
    condition = var.dead_letter.subscription_name == null || (
      length(var.dead_letter.subscription_name) >= 3 &&
      length(var.dead_letter.subscription_name) <= 255 &&
      can(regex("^[A-Za-z][A-Za-z0-9._~+%-]{2,254}$", var.dead_letter.subscription_name)) &&
      !startswith(lower(var.dead_letter.subscription_name), "goog")
    )
    error_message = "dead_letter.subscription_name must be null or a valid Pub/Sub subscription name."
  }
}

variable "push_config" {
  type = object({
    endpoint              = string
    service_account_email = string
    audience              = optional(string, null)
    no_wrapper            = optional(bool, false)
    write_metadata        = optional(bool, false)
  })
  description = "Optional authenticated push-delivery configuration. When null, the primary subscription remains pull-based."
  default     = null
  nullable    = true

  validation {
    condition = var.push_config == null || (
      startswith(var.push_config.endpoint, "https://") &&
      trimspace(var.push_config.service_account_email) != "" &&
      endswith(var.push_config.service_account_email, ".iam.gserviceaccount.com") &&
      (var.push_config.audience == null || trimspace(var.push_config.audience) != "") &&
      (!var.push_config.write_metadata || var.push_config.no_wrapper)
    )
    error_message = "push_config requires an HTTPS endpoint, a Google service account email, a non-empty audience when provided, and no_wrapper = true whenever write_metadata = true."
  }
}

variable "manage_service_agent_iam" {
  type        = bool
  description = "Whether the module grants the Pub/Sub service agent the minimum IAM needed for dead-letter forwarding and authenticated push token minting."
  default     = true
}

variable "labels" {
  type        = map(string)
  description = "Labels applied to Pub/Sub topics and subscriptions."
  default     = {}
}
