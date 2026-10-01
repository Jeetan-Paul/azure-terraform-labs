variable "prefix" {
  description = "Short lowercase name used in resource names."
  type        = string
  default     = "tflab"

  validation {
    condition     = can(regex("^[a-z0-9]{2,10}$", var.prefix))
    error_message = "prefix must be 2-10 lowercase letters or digits."
  }
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "westeurope"
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default = {
    project    = "azure-terraform-labs"
    lab        = "01"
    managed_by = "terraform"
    owner      = "jeetan"
  }
}
