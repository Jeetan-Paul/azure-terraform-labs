variable "name" {
  description = "Name of the virtual network."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to create everything in."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "address_space" {
  description = "Address ranges of the virtual network, for example [\"10.60.0.0/16\"]."
  type        = list(string)
}

variable "subnets" {
  description = "Subnets to create: subnet name => address range. Each one also gets an NSG."
  type        = map(string)
}

variable "tags" {
  description = "Tags for the virtual network and NSGs."
  type        = map(string)
  default     = {}
}
