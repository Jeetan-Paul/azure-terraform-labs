locals {
  tags = {
    project    = "azure-terraform-labs"
    lab        = "10"
    managed_by = "terraform"
    owner      = "jeetan"
  }

  # One inbound rule per allowed port, in the shape the NSG module expects.
  # Priorities 100, 110, 120, ... in the order of the list.
  security_rules = {
    for i, port in var.allowed_inbound_ports : "allow-${port}-in" => {
      name                       = "allow-${port}-in"
      priority                   = 100 + i * 10
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_address_prefix      = "Internet"
      source_port_range          = "*"
      destination_address_prefix = "*"
      destination_port_range     = tostring(port)
    }
  }
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-${var.prefix}-10"
  location = var.location
  tags     = local.tags
}

# Microsoft's NSG module. Pinned to one exact version: below 1.0, any new
# version may contain breaking changes.
module "nsg" {
  #checkov:skip=CKV_TF_1:Registry module pinned to one exact version; a Git commit hash would be stricter. See the README.
  source  = "Azure/avm-res-network-networksecuritygroup/azurerm"
  version = "0.6.0"

  name             = "nsg-${var.prefix}-10"
  location         = azurerm_resource_group.lab.location
  parent_id        = azurerm_resource_group.lab.id
  security_rules   = local.security_rules
  tags             = local.tags
  enable_telemetry = false
}

# Microsoft's virtual network module, with one subnet per entry in var.subnets.
# Its subnets are private by default (default_outbound_access_enabled = false).
module "vnet" {
  #checkov:skip=CKV_TF_1:Registry module pinned to one exact version; a Git commit hash would be stricter. See the README.
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.22.3"

  name          = "vnet-${var.prefix}-10"
  location      = azurerm_resource_group.lab.location
  parent_id     = azurerm_resource_group.lab.id
  address_space = [var.address_space]
  subnets = {
    for name, cidr in var.subnets : name => {
      name                   = name
      address_prefixes       = [cidr]
      network_security_group = { id = module.nsg.resource_id }
    }
  }
  tags             = local.tags
  enable_telemetry = false
}
