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

