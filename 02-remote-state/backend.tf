# Where Terraform keeps the state for this folder.
# Authenticates with your Azure CLI login and Entra ID, not a storage account key.
terraform {
  backend "azurerm" {
    use_cli              = true
    use_azuread_auth     = true
    storage_account_name = "sttfstate23461" # the $sa value from step 1
    container_name       = "tfstate"
    key                  = "02-remote-state.tfstate"
  }
}
