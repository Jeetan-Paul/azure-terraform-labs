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
  # "microsoft.insights" in lowercase on purpose: Azure lists that namespace in
  # lowercase, and with "Microsoft.Insights" the provider skips it silently
  # (debug log: "wasn't returned from the Azure API"). It's needed for the
  # diagnostic setting.
  resource_providers_to_register = ["Microsoft.App", "Microsoft.OperationalInsights", "microsoft.insights"]
  features {}
}
