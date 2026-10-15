locals {
  tags = {
    project    = "azure-terraform-labs"
    lab        = "09"
    managed_by = "terraform"
    owner      = "jeetan"
  }
}

resource "azurerm_resource_group" "lab" {
  location   = "westeurope"
  managed_by = null
  name       = "rg-tflab-09"
  tags       = local.tags
}

resource "azurerm_virtual_network" "lab" {
  location            = azurerm_resource_group.lab.location
  name                = "vnet-tflab-09"
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.90.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "app" {
  name                            = "snet-app"
  resource_group_name             = azurerm_resource_group.lab.name
  virtual_network_name            = azurerm_virtual_network.lab.name
  address_prefixes                = ["10.90.1.0/24"]
  default_outbound_access_enabled = false
}

resource "azurerm_network_security_group" "app" {
  location            = azurerm_resource_group.lab.location
  name                = "nsg-tflab-09-app"
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags

  security_rule {
    access                     = "Allow"
    destination_address_prefix = "*"
    destination_port_range     = "443"
    direction                  = "Inbound"
    name                       = "allow-https-in"
    priority                   = 100
    protocol                   = "Tcp"
    source_address_prefix      = "Internet"
    source_port_range          = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}