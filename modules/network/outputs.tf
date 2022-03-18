output "cloudeng_lab_resource_group" {
  value = azurerm_resource_group.cloudeng_lab
}

output "nic" {
  value = azurerm_network_interface.cloudeng_lab_nic
}
