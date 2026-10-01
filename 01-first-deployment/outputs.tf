output "resource_group_name" {
  value = azurerm_resource_group.lab.name
}

output "storage_account_name" {
  value = azurerm_storage_account.lab.name
}

output "storage_account_id" {
  value = azurerm_storage_account.lab.id
}
