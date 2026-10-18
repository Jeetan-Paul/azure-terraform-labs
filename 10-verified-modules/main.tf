terraform {
  required_version = ">= 1.16"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.6"
    }
    # The Azure Verified Modules talk to Azure through azapi: Azure's REST API,
    # one resource type per API version, instead of azurerm's hand-written resources.
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12"
    }
  }
}

# Login comes from environment variables: ARM_USE_OIDC in the pipeline,
# ARM_USE_CLI on your own PC. azapi reads the same ARM_* variables.
provider "azurerm" {
  resource_providers_to_register = ["Microsoft.Network"]
  features {}
}

provider "azapi" {}
