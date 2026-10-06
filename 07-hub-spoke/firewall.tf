# Azure Firewall in the hub, plus route tables that send spoke traffic through it.
# Switched on and off with var.enable_firewall. Costs money every hour it exists.

resource "azurerm_subnet" "firewall" {
  count = var.enable_firewall ? 1 : 0

  # Azure requires exactly this name, and at least a /26. No NSG allowed on it,
  # which is why it isn't made with the vnet module.
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = module.hub.name
  address_prefixes     = ["10.70.0.0/26"]
}

resource "azurerm_public_ip" "firewall" {
  count = var.enable_firewall ? 1 : 0

  name                = "pip-fw-${var.prefix}-hub"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_firewall_policy" "hub" {
  count = var.enable_firewall ? 1 : 0

  #checkov:skip=CKV_AZURE_220:IDPS needs the Premium tier; this lab uses Standard to keep the cost down.

  name                     = "afwp-${var.prefix}-hub"
  resource_group_name      = azurerm_resource_group.network.name
  location                 = azurerm_resource_group.network.location
  sku                      = "Standard"
  threat_intelligence_mode = "Deny"
  tags                     = var.tags
}

resource "azurerm_firewall_policy_rule_collection_group" "hub" {
  count = var.enable_firewall ? 1 : 0

  name               = "rcg-lab07"
  firewall_policy_id = azurerm_firewall_policy.hub[0].id
  priority           = 100

  network_rule_collection {
    name     = "allow-spoke-to-spoke"
    priority = 100
    action   = "Allow"

    rule {
      name                  = "ping-between-spokes"
      protocols             = ["ICMP"]
      source_addresses      = ["10.71.0.0/16", "10.72.0.0/16"]
      destination_addresses = ["10.71.0.0/16", "10.72.0.0/16"]
      destination_ports     = ["*"]
    }
  }

  network_rule_collection {
    name     = "allow-azure-management"
    priority = 200
    action   = "Allow"

    # Run Command needs port 443 to Azure public IPs to send back its results.
    rule {
      name                  = "vm-agent-to-azure"
      protocols             = ["TCP"]
      source_addresses      = ["10.71.0.0/16", "10.72.0.0/16"]
      destination_addresses = ["AzureCloud"]
      destination_ports     = ["443"]
    }
  }
}

resource "azurerm_firewall" "hub" {
  count = var.enable_firewall ? 1 : 0

  #checkov:skip=CKV_AZURE_216:Threat intelligence is set to Deny in the attached firewall policy; this check is for classic-rules firewalls.

  name                = "afw-${var.prefix}-hub"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.hub[0].id
  tags                = var.tags

  ip_configuration {
    name                 = "ipconfig"
    subnet_id            = azurerm_subnet.firewall[0].id
    public_ip_address_id = azurerm_public_ip.firewall[0].id
  }

  # The rules must exist before traffic is routed through the firewall.
  depends_on = [azurerm_firewall_policy_rule_collection_group.hub]
}

# One route table per spoke: everything that isn't local or the hub
# goes to the firewall (0.0.0.0/0 -> firewall's private IP).

resource "azurerm_route_table" "spoke" {
  for_each = var.enable_firewall ? local.spokes : {}

  name                          = "rt-${each.key}"
  resource_group_name           = azurerm_resource_group.network.name
  location                      = azurerm_resource_group.network.location
  bgp_route_propagation_enabled = false
  tags                          = var.tags

  route {
    name                   = "default-via-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.hub[0].ip_configuration[0].private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "spoke" {
  for_each = var.enable_firewall ? local.spokes : {}

  subnet_id      = each.value.subnet_ids["snet-app"]
  route_table_id = azurerm_route_table.spoke[each.key].id
}
