output "hub_vnet_id" {
  value = module.hub.id
}

output "spoke_vnet_id" {
  value = module.spoke.id
}

output "spoke_subnet_ids" {
  value = module.spoke.subnet_ids
}
