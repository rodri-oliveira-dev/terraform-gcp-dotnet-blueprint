variable "project_id" {
  type        = string
  description = "Google Cloud project used by the isolated VPC networking example."
}

variable "region" {
  type        = string
  description = "Region used by the example workload subnet."
  default     = "us-central1"
}
