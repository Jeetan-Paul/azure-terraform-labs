# State for this folder. Same storage as projects 02 and 04.
# No login method here: the pipeline sets ARM_USE_OIDC=true,
# on your own PC you set ARM_USE_CLI=true.
terraform {
  backend "azurerm" {
    use_azuread_auth     = true
    storage_account_name = "sttfstate23461"
    container_name       = "tfstate"
    key                  = "06-modules.tfstate"
  }
}
