output "test_vm_ids" {
  description = "Resource IDs of the test VMs."
  value       = { for name, vm in azurerm_linux_virtual_machine.test : name => vm.id }
}

output "firewall_private_ip" {
  description = "The firewall's private IP, or null when the firewall is off."
  value       = one(azurerm_firewall.hub[*].ip_configuration[0].private_ip_address)
}
