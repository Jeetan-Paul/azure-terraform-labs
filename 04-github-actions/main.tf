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

# Login comes from environment variables: ARM_USE_OIDC, ARM_CLIENT_ID,
# ARM_TENANT_ID and ARM_SUBSCRIPTION_ID in the pipeline.
provider "azurerm" {
  resource_providers_to_register = ["Microsoft.Storage"]
  features {}
}