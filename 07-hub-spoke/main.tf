terraform {
  required_version = ">= 1.16"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.6"
    }
  }
}

# Login comes from environment variables: ARM_USE_OIDC in the pipeline,
# ARM_USE_CLI on your own PC.
provider "azurerm" {
  resource_providers_to_register = ["Microsoft.Network", "Microsoft.Compute"]
  features {}
}

resource "azurerm_resource_group" "network" {
  name     = "rg-${var.prefix}-07"
  location = var.location
  tags     = var.tags
}

# Three networks from the module you built in project 06.

module "hub" {
  source = "../06-modules/modules/vnet"

  name                = "vnet-${var.prefix}-hub"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  address_space       = ["10.70.0.0/16"]
  subnets = {
    "snet-shared" = "10.70.1.0/24"
  }
  tags = var.tags
}

module "spoke1" {
  source = "../06-modules/modules/vnet"

  name                = "vnet-${var.prefix}-spoke1"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  address_space       = ["10.71.0.0/16"]
  subnets = {
    "snet-app" = "10.71.1.0/24"
  }
  tags = var.tags
}

module "spoke2" {
  source = "../06-modules/modules/vnet"

  name                = "vnet-${var.prefix}-spoke2"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  address_space       = ["10.72.0.0/16"]
  subnets = {
    "snet-app" = "10.72.1.0/24"
  }
  tags = var.tags
}

locals {
  spokes = {
    spoke1 = module.spoke1
    spoke2 = module.spoke2
  }
}

# Peering is always a pair: hub -> spoke and spoke -> hub.
# The spokes are NOT peered with each other.

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  for_each = local.spokes

  name                      = "peer-hub-to-${each.key}"
  resource_group_name       = azurerm_resource_group.network.name
  virtual_network_name      = module.hub.name
  remote_virtual_network_id = each.value.id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  for_each = local.spokes

  name                      = "peer-${each.key}-to-hub"
  resource_group_name       = azurerm_resource_group.network.name
  virtual_network_name      = each.value.name
  remote_virtual_network_id = module.hub.id
  allow_forwarded_traffic   = true
}
