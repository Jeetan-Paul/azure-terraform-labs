output "vnet_id" {
  description = "Azure ID of the virtual network."
  value       = module.vnet.resource_id
}

output "nsg_id" {
  description = "Azure ID of the network security group."
  value       = module.nsg.resource_id
}
