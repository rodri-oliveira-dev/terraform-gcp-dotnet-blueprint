variable "project_id" {
  type        = string
  description = "Google Cloud project ID used by the example."

  validation {
    condition     = trimspace(var.project_id) != ""
    error_message = "project_id must not be empty."
  }
}

variable "labels" {
  type        = map(string)
  description = "Labels applied to Secret Manager resources in this example."
  default = {
    managed_by = "terraform"
    example    = "runtime-secrets"
  }
}
