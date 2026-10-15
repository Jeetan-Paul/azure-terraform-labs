# Which existing Azure resources Terraform should adopt, and where to put them.
# `to` = the resource block in network.tf, `id` = the resource's Azure ID.
#
# The subscription ID is looked up at plan time instead of typed in,
# so it never ends up in this public repo.

data "azurerm_client_config" "current" {}

locals {
  rg_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/rg-tflab-09"
}

import {
  to = azurerm_resource_group.lab
  id = local.rg_id
}

import {
  to = azurerm_virtual_network.lab
  id = "${local.rg_id}/providers/Microsoft.Network/virtualNetworks/vnet-tflab-09"
}

import {
  to = azurerm_subnet.app
  id = "${local.rg_id}/providers/Microsoft.Network/virtualNetworks/vnet-tflab-09/subnets/snet-app"
}

import {
  to = azurerm_network_security_group.app
  id = "${local.rg_id}/providers/Microsoft.Network/networkSecurityGroups/nsg-tflab-09-app"
}

# The association has no ID of its own: Azure stores it on the subnet,
# so its import ID is the subnet's ID (azurerm docs).
import {
  to = azurerm_subnet_network_security_group_association.app
  id = "${local.rg_id}/providers/Microsoft.Network/virtualNetworks/vnet-tflab-09/subnets/snet-app"
}
