# Tests for this folder. Run them with: terraform test
#
# The providers are mocked: Terraform pretends to be Azure and makes up values,
# so the tests need no login and create nothing. `command = plan` stops each
# run after the plan.

mock_provider "azurerm" {}
mock_provider "azapi" {}

# With the default settings: names follow the convention, and only HTTPS is open.
run "defaults" {
  command = plan

  assert {
    condition     = azurerm_resource_group.lab.name == "rg-tflab-10"
    error_message = "The resource group name doesn't follow the naming convention."
  }

  assert {
    condition     = azurerm_resource_group.lab.tags["managed_by"] == "terraform"
    error_message = "Every resource should carry the managed_by = terraform tag."
  }

  assert {
    condition     = keys(local.security_rules) == ["allow-443-in"]
    error_message = "By default only HTTPS (443) should be open."
  }
}

# Someone tries to open SSH to the internet: the validation must stop it.
run "ssh_from_internet_is_refused" {
  command = plan

  variables {
    allowed_inbound_ports = [443, 22]
  }

  expect_failures = [var.allowed_inbound_ports]
}

# A typo in the address range must be caught before Azure sees it.
run "bad_address_space_is_refused" {
  command = plan

  variables {
    address_space = "10.100.0.0/33"
  }

  expect_failures = [var.address_space]
}

run "rdp_from_internet_is_refused" {
  command = plan

  variables {
    allowed_inbound_ports = [443, 3389]
  }

  expect_failures = [var.allowed_inbound_ports]
}