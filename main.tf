module "cloudeng_lab_networking" {
  source = "./modules/network"

  global_settings = var.global_settings
}
# random id
resource "random_id" "randomId" {
  keepers = {
    resource_group = module.cloudeng_lab_networking.cloudeng_lab_resource_group.name
  }

  byte_length = 8
}

# storae account for boot diagnostics
resource "azurerm_storage_account" "cloudeng_lab_sa" {
  name                     = "diag${random_id.randomId.hex}"
  resource_group_name      = module.cloudeng_lab_networking.cloudeng_lab_resource_group.name
  location                 = var.global_settings.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = var.global_settings.tags
}

# create and display SSH key
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
output "tls_private_key" {
  value     = tls_private_key.ssh.private_key_pem
  sensitive = true
}

# VM
resource "azurerm_linux_virtual_machine" "cloudeng_lab_linux_vm" {
  name                  = "cloudeng_linux"
  location              = var.global_settings.location
  resource_group_name   = module.cloudeng_lab_networking.cloudeng_lab_resource_group.name
  network_interface_ids = [module.cloudeng_lab_networking.nic.id]
  size                  = "Standard_DS1_v2"

  os_disk {
    name                 = var.linux_settings.os_disk_name
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = var.linux_settings.sku
    version   = var.linux_settings.version
  }

  computer_name                   = var.linux_settings.computer_name
  admin_username                  = var.linux_settings.admin_username
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.linux_settings.admin_username
    public_key = tls_private_key.ssh.public_key_openssh
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.cloudeng_lab_sa.primary_blob_endpoint
  }

  tags = var.global_settings.tags
}

