resource "azurerm_resource_group" "cloudeng_lab" {
  name     = var.global_settings.resource_group_name
  location = var.global_settings.location

  tags = var.global_settings.tags
}
module "linux_networking" {
  source                  = "./modules/network"
  resource_group          = azurerm_resource_group.cloudeng_lab
  global_settings         = var.global_settings
  address_space           = ["10.0.0.0/16"]
  subnet_name             = "linux-subnet"
  subnet_address_prefixes = ["10.0.101.0/24"]
  public_ip_name          = "linux_publicip"
  nic = {
    name         = "linux_nic"
    nic_cfg_name = "linux_nic_cfg"
  }
}

# module "windows_networking" {
#   source                  = "./modules/network"
#   resource_group          = azurerm_resource_group.cloudeng_lab
#   global_settings         = var.global_settings
#   address_space           = ["10.0.0.0/16"]
#   subnet_name             = "win-subnet"
#   subnet_address_prefixes = ["10.0.102.0/24"]
#   public_ip_name          = "windows_publicip"
#   nic = {
#     name         = "windows_nic"
#     nic_cfg_name = "windows_nic_cfg"
#   }
# }

# random id
resource "random_id" "randomId" {
  keepers = {
    resource_group = azurerm_resource_group.cloudeng_lab.name
  }

  byte_length = 8
}

# storae account for boot diagnostics
resource "azurerm_storage_account" "cloudeng_lab_sa" {
  name                     = "diag${random_id.randomId.hex}"
  resource_group_name      = azurerm_resource_group.cloudeng_lab.name
  location                 = var.global_settings.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = var.global_settings.tags
}

# create and display SSH key
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096

  provisioner "local-exec" {
    command = "echo '${tls_private_key.ssh.private_key_pem}' > ${var.private_key_path}"
  }
}
output "tls_private_key" {
  value     = tls_private_key.ssh.private_key_pem
  sensitive = true
}

# VM
resource "azurerm_linux_virtual_machine" "cloudeng_lab_linux_vm" {
  name                  = var.linux_settings.name
  location              = var.global_settings.location
  resource_group_name   = azurerm_resource_group.cloudeng_lab.name
  network_interface_ids = [module.linux_networking.nic.id]
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

  tags = merge(var.global_settings.tags, var.linux_settings.tags)
}

resource "null_resource" "install_java_linux" {
  count = length(azurerm_linux_virtual_machine.cloudeng_lab_linux_vm.*.id)

  triggers = {
    uuid = element(azurerm_linux_virtual_machine.cloudeng_lab_linux_vm.*.public_ip_address, count.index)
  }
  connection {
    user        = var.linux_settings.admin_username
    private_key = file("${var.private_key_path}")
    agent       = true
    timeout     = "5m"
    host        = element(azurerm_linux_virtual_machine.cloudeng_lab_linux_vm.*.public_ip_address, count.index)
  }

  provisioner "local-exec" {
    command = "StrictHostKeyChecking=no ansible-playbook -u ${var.linux_settings.admin_username} --key-file '${var.private_key_path}' -i ./ansible/inventory ./ansible/playbook/java/linux-java-install.yaml"
  }
}

# resource "azurerm_windows_virtual_machine" "cloudeng_lab_windows_vm" {
#   name                  = var.windows_settings.name
#   resource_group_name   = azurerm_resource_group.cloudeng_lab.name
#   location              = var.global_settings.location
#   size                  = "Standard_F2"
#   admin_username        = var.windows_settings.admin_username
#   admin_password        = var.windows_settings.admin_password
#   network_interface_ids = [module.windows_networking.nic.id]

#   os_disk {
#     caching              = "ReadWrite"
#     storage_account_type = "Standard_LRS"
#   }
#   computer_name = var.windows_settings.name
#   custom_data   = filebase64("./files/winrm.ps1")

#   winrm_listener {
#     protocol = "Http"
#   }

#   additional_unattend_content {
#     content = "<AutoLogon><Password><Value>${var.windows_settings.admin_password}</Value></Password><Enabled>true</Enabled><LogonCount>1</LogonCount><Username>${var.windows_settings.admin_username}</Username></AutoLogon>"
#     setting = "AutoLogon"
#   }

#   additional_unattend_content {
#     content = file("./files/AutoLogon.xml")
#     setting = "FirstLogonCommands"
#   }
#   source_image_reference {
#     publisher = "MicrosoftWindowsServer"
#     offer     = "WindowsServer"
#     sku       = "2019-Datacenter"
#     version   = "latest"
#   }

#   tags = merge(var.global_settings.tags, var.windows_settings.tags)
# }

# resource "null_resource" "install_java_windows" {
#   count = length(azurerm_windows_virtual_machine.cloudeng_lab_windows_vm.*.id)

#   connection {
#     type     = "winrm"
#     user     = "Administrator"
#     password = var.windows_settings.admin_password
#     port     = 5985
#     https    = true
#     timeout  = "5m"
#     host     = element(azurerm_windows_virtual_machine.cloudeng_lab_windows_vm.*.public_ip_address, count.index)
#   }
#   provisioner "file" {
#     source      = "files/test.txt"
#     destination = "C:/terraform/test.txt"
#   }

#   provisioner "remote-exec" {
#     inline = ["PowerShell.exe -ExecutionPolicy Bypass c:\\terraform\\config.ps1", ]
#   }
#   provisioner "local-exec" {

#     command = "ansible-playbook -i ./ansible/inventory ./ansible/playbook/java/windows-java-install.yaml"
#   }
# }


