# State in the shared storage account, logged in with Entra ID.
# In the pipeline the login comes from ARM_USE_OIDC;
# on your own PC you set ARM_USE_CLI=true.
terraform {
  backend "azurerm" {
    use_azuread_auth     = true
    storage_account_name = "sttfstate23461"
    container_name       = "tfstate"
    key                  = "11-container-app.tfstate"
  }
}
