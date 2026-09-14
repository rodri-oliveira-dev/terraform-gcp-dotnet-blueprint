variable "project_id" {
  description = "Google Cloud project that hosts the Workload Identity Federation configuration."
  type        = string

  validation {
    condition     = length(trimspace(var.project_id)) > 0
    error_message = "project_id must not be empty."
  }
}

variable "github_owner_id" {
  description = "Immutable numeric GitHub owner ID trusted by the provider."
  type        = string
  default     = "3470248"

  validation {
    condition     = can(regex("^[0-9]+$", var.github_owner_id))
    error_message = "github_owner_id must contain only digits."
  }
}

variable "github_repository_id" {
  description = "Immutable numeric GitHub repository ID trusted by the provider."
  type        = string
  default     = "1370437821"

  validation {
    condition     = can(regex("^[0-9]+$", var.github_repository_id))
    error_message = "github_repository_id must contain only digits."
  }
}

variable "github_ref" {
  description = "Git ref allowed to exchange GitHub OIDC tokens for Google Cloud credentials."
  type        = string
  default     = "refs/heads/main"

  validation {
    condition     = startswith(var.github_ref, "refs/")
    error_message = "github_ref must be a fully-qualified Git ref such as refs/heads/main."
  }
}

variable "workload_identity_pool_id" {
  description = "Workload Identity Pool ID."
  type        = string
  default     = "github-actions"
}

variable "workload_identity_provider_id" {
  description = "GitHub OIDC provider ID within the Workload Identity Pool."
  type        = string
  default     = "github"
}

variable "deployment_service_account_id" {
  description = "Service account ID impersonated by trusted GitHub Actions jobs."
  type        = string
  default     = "github-actions-deployer"
}

variable "deployment_project_roles" {
  description = "Optional project-level IAM roles granted to the deployment service account. Keep empty until a concrete workflow requires a role."
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for role in var.deployment_project_roles : startswith(role, "roles/") && !contains(["roles/owner", "roles/editor"], role)
    ])
    error_message = "deployment_project_roles must contain predefined roles and must not include roles/owner or roles/editor."
  }
}
