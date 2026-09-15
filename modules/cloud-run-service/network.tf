variable "direct_vpc" {
  type = object({
    network    = string
    subnetwork = string
    egress     = optional(string, "PRIVATE_RANGES_ONLY")
    tags       = optional(set(string), [])
  })
  description = "Optional Direct VPC egress configuration. When null, the service remains network-agnostic. Network and subnetwork should be names from the target VPC; egress defaults to PRIVATE_RANGES_ONLY."
  default     = null
  nullable    = true

  validation {
    condition = var.direct_vpc == null ? true : (
      trimspace(var.direct_vpc.network) != "" &&
      trimspace(var.direct_vpc.subnetwork) != "" &&
      contains(["PRIVATE_RANGES_ONLY", "ALL_TRAFFIC"], var.direct_vpc.egress) &&
      alltrue([
        for tag in var.direct_vpc.tags :
        length(tag) >= 1 &&
        length(tag) <= 63 &&
        can(regex("^[a-z]([-a-z0-9]*[a-z0-9])?$", tag))
      ])
    )
    error_message = "direct_vpc must provide non-empty network/subnetwork names, egress must be PRIVATE_RANGES_ONLY or ALL_TRAFFIC, and network tags must be valid lowercase RFC1035-style names up to 63 characters."
  }
}
