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
  description = "Tags applied to every resource."
  type        = map(string)
  default = {
    project    = "azure-terraform-labs"
    lab        = "05"
    managed_by = "terraform"
    owner      = "jeetan"
  }
}

variable "admin_ip" {
  description = "My public IP address, for remote access."
  type = string
  default     = "203.0.113.10/32"
}

