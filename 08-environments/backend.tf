# State storage for all three environments. The `key` (the state file's name)
# is left out on purpose: it's given at init, one per environment:
#   terraform init -backend-config="key=08-environments-dev.tfstate"
# That's a "partial backend configuration".
terraform {
  backend "azurerm" {
    use_azuread_auth     = true
    storage_account_name = "sttfstate23461"
    container_name       = "tfstate"
  }
}
