# resource "local_file" "ansible_inven" {
#   content = templatefile("${path.module}/ansible/inventory.tpl",
#     {
#       linux_public_ip = azurerm_linux_virtual_machine.cloudeng_lab_linux_vm.*.public_ip_address
#     }
#   )
#   filename = "${path.module}/ansible/inventory"
# }

data "template_file" "inventory_cfg" {
  template = file("${path.module}/ansible/inventory.tpl")

  vars = {
    linux_public_ip = "${join("\n", azurerm_linux_virtual_machine.cloudeng_lab_linux_vm.*.public_ip_address)}"
  }
}

resource "local_file" "save_inven" {
  content  = data.template_file.inventory_cfg.rendered
  filename = "./ansible/inventory.yaml"
}
