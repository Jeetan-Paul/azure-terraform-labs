variable "prefix" {
  description = "Short lowercase name used in resource names."
  type        = string
  default     = "tflab"
}

variable "location" {
  description = "Azure region. Sweden Central, because the cheap B-series VM sizes aren't available to this subscription in West Europe."
  type        = string
  default     = "swedencentral"
}

variable "vm_size" {
  description = "Size of the test VMs."
  type        = string
  default     = "Standard_B2ats_v2"
}

variable "enable_test_vms" {
  description = "Create the two test VMs (one per spoke)."
  type        = bool
  default     = true
}

variable "enable_firewall" {
  description = "Create Azure Firewall in the hub and route the spokes through it. Costs about EUR 1.10 per hour."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to every resource that supports them."
  type        = map(string)
  default = {
    project    = "azure-terraform-labs"
    lab        = "07"
    managed_by = "terraform"
    owner      = "jeetan"
  }
}
