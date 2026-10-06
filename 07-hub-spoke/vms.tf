# Two small test VMs, one per spoke. Switched on and off with var.enable_test_vms.
# No public IP: we only look at them through Azure (Network Watcher, Run Command).

locals {
  test_vms = {
    spoke1 = {
      subnet_id = module.spoke1.subnet_ids["snet-app"]
      ip        = "10.71.1.10"
    }
    spoke2 = {
      subnet_id = module.spoke2.subnet_ids["snet-app"]
      ip        = "10.72.1.10"
    }
  }
}

resource "azurerm_network_interface" "test" {
  for_each = var.enable_test_vms ? local.test_vms : {}

  name                = "nic-vm-${each.key}"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = each.value.subnet_id
    private_ip_address_allocation = "Static"
    private_ip_address            = each.value.ip
  }
}

resource "azurerm_linux_virtual_machine" "test" {
  for_each = var.enable_test_vms ? local.test_vms : {}

  #checkov:skip=CKV_AZURE_50:Run Command, which this lab uses for the ping test, is a VM extension.

  name                  = "vm-${each.key}"
  resource_group_name   = azurerm_resource_group.network.name
  location              = azurerm_resource_group.network.location
  size                  = var.vm_size
  network_interface_ids = [azurerm_network_interface.test[each.key].id]
  tags                  = var.tags

  admin_username                  = "azureuser"
  disable_password_authentication = true

  # Only the public key is in the repo. The private key stays on your PC.
  admin_ssh_key {
    username   = "azureuser"
    public_key = file("${path.module}/ssh/tflab07.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}
