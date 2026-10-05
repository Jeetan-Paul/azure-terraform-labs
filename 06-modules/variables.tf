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
  description = "Tags applied to every resource that supports them."
  type        = map(string)
  default = {
    project    = "azure-terraform-labs"
    lab        = "06"
    managed_by = "terraform"
    owner      = "jeetan"
  }
}
