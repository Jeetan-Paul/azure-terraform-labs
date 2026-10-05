# TFLint settings for every folder in this repo.
# The checks workflow runs: tflint --recursive --config "$(pwd)/.tflint.hcl"

# Built-in Terraform rules (unused variables, missing version pins, naming, ...).
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# Azure rules (invalid VM sizes, wrong argument values, ...).
plugin "azurerm" {
  enabled = true
  version = "0.32.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}

# Off on purpose: lab resources must be destroyable at the end of each project.
# In production you'd keep this on for storage accounts and other resources holding data.
rule "azurerm_resources_missing_prevent_destroy" {
  enabled = false
}
