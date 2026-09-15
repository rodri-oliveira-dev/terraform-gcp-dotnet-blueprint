variable "project_id" {
  type        = string
  description = "Google Cloud project ID where the VPC networking resources are created."

  validation {
    condition     = trimspace(var.project_id) != ""
    error_message = "project_id must not be empty."
  }
}

variable "network_name" {
  type        = string
  description = "Name of the custom-mode VPC network."

  validation {
    condition = (
      length(var.network_name) >= 1 &&
      length(var.network_name) <= 63 &&
      can(regex("^[a-z]([-a-z0-9]*[a-z0-9])?$", var.network_name))
    )
    error_message = "network_name must be 1-63 characters, start with a lowercase letter, contain only lowercase letters, digits, or hyphens, and end with a lowercase letter or digit."
  }
}

variable "routing_mode" {
  type        = string
  description = "Network-wide dynamic routing mode."
  default     = "REGIONAL"

  validation {
    condition     = contains(["REGIONAL", "GLOBAL"], var.routing_mode)
    error_message = "routing_mode must be REGIONAL or GLOBAL."
  }
}

variable "mtu" {
  type        = number
  description = "VPC network MTU in bytes."
  default     = 1460

  validation {
    condition     = var.mtu >= 1300 && var.mtu <= 8896 && floor(var.mtu) == var.mtu
    error_message = "mtu must be an integer from 1300 through 8896 bytes."
  }
}

variable "subnet_name" {
  type        = string
  description = "Name of the regional subnet used by workloads."

  validation {
    condition = (
      length(var.subnet_name) >= 1 &&
      length(var.subnet_name) <= 63 &&
      can(regex("^[a-z]([-a-z0-9]*[a-z0-9])?$", var.subnet_name))
    )
    error_message = "subnet_name must be 1-63 characters, start with a lowercase letter, contain only lowercase letters, digits, or hyphens, and end with a lowercase letter or digit."
  }
}

variable "subnet_region" {
  type        = string
  description = "Google Cloud region for the workload subnet."

  validation {
    condition     = trimspace(var.subnet_region) != ""
    error_message = "subnet_region must not be empty."
  }
}

variable "subnet_ip_cidr_range" {
  type        = string
  description = "Primary IPv4 CIDR range for the workload subnet."

  validation {
    condition = (
      can(cidrnetmask(var.subnet_ip_cidr_range)) &&
      try(tonumber(split("/", var.subnet_ip_cidr_range)[1]), 99) >= 4 &&
      try(tonumber(split("/", var.subnet_ip_cidr_range)[1]), 99) <= 29
    )
    error_message = "subnet_ip_cidr_range must be a valid IPv4 CIDR block with a prefix length from /4 through /29."
  }
}

variable "private_ip_google_access" {
  type        = bool
  description = "Whether resources using the subnet can reach Google APIs without external IP addresses."
  default     = true
}

variable "private_service_access_range_name" {
  type        = string
  description = "Name of the global internal range reserved for Private Service Access."

  validation {
    condition = (
      length(var.private_service_access_range_name) >= 1 &&
      length(var.private_service_access_range_name) <= 63 &&
      can(regex("^[a-z]([-a-z0-9]*[a-z0-9])?$", var.private_service_access_range_name))
    )
    error_message = "private_service_access_range_name must be a valid 1-63 character RFC1035-style resource name."
  }
}

variable "private_service_access_cidr" {
  type        = string
  description = "Explicit IPv4 CIDR block reserved for Private Service Access. Use a range that does not overlap workload subnets or other routed networks."

  validation {
    condition = (
      can(cidrnetmask(var.private_service_access_cidr)) &&
      try(tonumber(split("/", var.private_service_access_cidr)[1]), 99) >= 8 &&
      try(tonumber(split("/", var.private_service_access_cidr)[1]), 99) <= 24
    )
    error_message = "private_service_access_cidr must be a valid IPv4 CIDR block with a prefix length from /8 through /24."
  }
}

variable "private_service_access_deletion_policy" {
  type        = string
  description = "Deletion policy for the Service Networking connection. PREVENT is the safe default; use DELETE only for an explicitly disposable network."
  default     = "PREVENT"

  validation {
    condition     = contains(["PREVENT", "DELETE"], var.private_service_access_deletion_policy)
    error_message = "private_service_access_deletion_policy must be PREVENT or DELETE."
  }
}
