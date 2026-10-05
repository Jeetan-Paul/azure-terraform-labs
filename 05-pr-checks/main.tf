terraform {
  required_version = ">= 1.16"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.6"
    }
  }
}

# This project isn't deployed. The checks only read the code.
provider "azurerm" {
  resource_providers_to_register = ["Microsoft.Network"]
  features {}
}

resource "azurerm_resource_group" "checks" {
  name     = "rg-${var.prefix}-05"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "checks" {
  name                = "vnet-${var.prefix}-05"
  resource_group_name = azurerm_resource_group.checks.name
  location            = azurerm_resource_group.checks.location
  address_space       = ["10.50.0.0/16"]
  tags                = var.tags
}

resource "azurerm_subnet" "workload" {
  name                 = "snet-workload"
  resource_group_name  = azurerm_resource_group.checks.name
  virtual_network_name = azurerm_virtual_network.checks.name
  address_prefixes     = ["10.50.1.0/24"]
}

resource "azurerm_network_security_group" "workload" {
  name                = "nsg-workload"
  resource_group_name = azurerm_resource_group.checks.name
  location            = azurerm_resource_group.checks.location
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "workload" {
  subnet_id                 = azurerm_subnet.workload.id
  network_security_group_id = azurerm_network_security_group.workload.id
}
