variable "client_name" {
  description = "Client identifier (used for project name, resource names, subdomain)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.client_name))
    error_message = "Client name must be 3-21 chars, start with letter, lowercase alphanumeric and hyphens only."
  }
}

variable "client_domain" {
  description = "Client's custom domain (optional, can be added later)"
  type        = string
  default     = ""
}

variable "admin_project_id" {
  description = "Admin project ID where Terraform state bucket lives"
  type        = string
  default     = "axxe-agency-admin"
}

variable "billing_account_id" {
  description = "Billing account ID to link new projects to"
  type        = string
  default     = "01B710-DCC5DF-7BF035"
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "europe-west1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "europe-west1-b"
}

variable "machine_type" {
  description = "VM machine type"
  type        = string
  default     = "e2-small"
}

variable "boot_disk_size_gb" {
  description = "Boot disk size in GB"
  type        = number
  default     = 20
}

variable "data_disk_size_gb" {
  description = "Data disk size in GB (for Ghost content and MySQL)"
  type        = number
  default     = 50
}

variable "repo_url" {
  description = "Git repository URL containing compose.yml and configs"
  type        = string
  default     = "https://github.com/axxetech/ghost-google.git"
}

variable "repo_branch" {
  description = "Git branch to clone"
  type        = string
  default     = "main"
}
