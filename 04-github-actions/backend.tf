# State for this folder, in the same storage account as project 02.
# No login method here on purpose: the pipeline sets ARM_USE_OIDC=true,
# and on your own PC you set ARM_USE_CLI=true. The same code works in both places.
terraform {
  backend "azurerm" {
    use_azuread_auth     = true
    storage_account_name = "sttfstate23461"
    container_name       = "tfstate"
    key                  = "04-github-actions.tfstate"
  }
}
