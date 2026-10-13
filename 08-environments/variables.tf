variable "environment" {
  description = "Which environment this is: dev, test or prod."
  type        = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be dev, test or prod."
  }
}

variable "address_space" {
  description = "Address range of this environment's virtual network."
  type        = string
}

variable "subnets" {
  description = "Subnets for this environment: name => address range."
  type        = map(string)
}

variable "prefix" {
  description = "Short lowercase name used in resource names."
  type        = string
  default     = "tflab"
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "westeurope"
}

variable "tags" {
  description = "Tags applied to every resource. The environment tag is added automatically."
  type        = map(string)
  default = {
    project    = "azure-terraform-labs"
    lab        = "08"
    managed_by = "terraform"
    owner      = "jeetan"
  }
}
