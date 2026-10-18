variable "prefix" {
  description = "Short lowercase name used in resource names."
  type        = string
  default     = "tflab"
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "westeurope"
}

variable "address_space" {
  description = "Address range of the virtual network."
  type        = string
  default     = "10.100.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.address_space))
    error_message = "address_space must be a valid IPv4 CIDR range, such as 10.100.0.0/16."
  }
}

variable "subnets" {
  description = "Subnets to create: name => address range. All of them get the NSG."
  type        = map(string)
  default = {
    "snet-app"  = "10.100.1.0/24"
    "snet-data" = "10.100.2.0/24"
  }
}

variable "allowed_inbound_ports" {
  description = "TCP ports that may be reached from the internet."
  type        = list(number)
  default     = [443,22]

  validation {
    condition     = !contains(var.allowed_inbound_ports, 22) && !contains(var.allowed_inbound_ports, 3389)
    error_message = "SSH (22) and RDP (3389) may not be opened to the internet. Use Azure Bastion instead."
  }
}