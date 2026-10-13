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

# The same code for dev, test and prod. What differs per environment
# comes from envs/<environment>.tfvars.

locals {
  tags = merge(var.tags, { environment = var.environment })
}

resource "azurerm_resource_group" "env" {
  name     = "rg-${var.prefix}-08-${var.environment}"
  location = var.location
  tags     = local.tags
}

module "network" {
  source = "../06-modules/modules/vnet"

  name                = "vnet-${var.prefix}-08-${var.environment}"
  resource_group_name = azurerm_resource_group.env.name
  location            = azurerm_resource_group.env.location
  address_space       = [var.address_space]
  subnets             = var.subnets
  tags                = local.tags
}
