output "id" {
  description = "Resource ID of the virtual network."
  value       = azurerm_virtual_network.this.id
}

output "name" {
  description = "Name of the virtual network."
  value       = azurerm_virtual_network.this.name
}

output "subnet_ids" {
  description = "Subnet name => subnet resource ID."
  value       = { for name, subnet in azurerm_subnet.this : name => subnet.id }
}
