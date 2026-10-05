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
  resource_providers_to_register = ["Microsoft.Network"]
  features {}
}

resource "azurerm_resource_group" "network" {
  name     = "rg-${var.prefix}-06"
  location = var.location
  tags     = var.tags
}

# The same building block (module), used twice with different inputs.

module "hub" {
  source = "./modules/vnet"

  name                = "vnet-${var.prefix}-hub"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  address_space       = ["10.60.0.0/16"]
  subnets = {
    "snet-shared" = "10.60.1.0/24"
  }
  tags = var.tags
}

module "spoke" {
  source = "./modules/vnet"

  name                = "vnet-${var.prefix}-spoke"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  address_space       = ["10.61.0.0/16"]
  subnets = {
    "snet-app"  = "10.61.1.0/24"
    "snet-data" = "10.61.2.0/24"
    "snet-web"  = "10.61.3.0/24"
  }
  tags = var.tags
}

module "spoke2" {
  source = "./modules/vnet"

  name                = "vnet-${var.prefix}-spoke2"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  address_space       = ["10.62.0.0/16"]
  subnets = {
    "snet-app" = "10.62.1.0/24"
  }
  tags = var.tags
}

