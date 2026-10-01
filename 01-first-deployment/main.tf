terraform {
  required_version = ">= 1.16"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.6"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }
  }
}

# Subscription comes from `az account show` (or ARM_SUBSCRIPTION_ID).
# From azurerm 5.0 the provider registers no resource providers by default,
# so list the ones this configuration needs.
provider "azurerm" {
  resource_providers_to_register = ["Microsoft.Storage"]
  features {}
}

# Storage account names must be globally unique, lowercase, 3-24 characters.
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-${var.prefix}-01"
  location = var.location
  tags     = var.tags
}

resource "azurerm_storage_account" "lab" {
  name                     = "st${var.prefix}${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.lab.name
  location                 = azurerm_resource_group.lab.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  tags                     = var.tags
}
