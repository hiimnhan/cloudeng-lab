# virtual network
resource "azurerm_virtual_network" "cloudeng_lab_vnetwork" {
  name                = "cloudeng_network"
  address_space       = var.address_space
  location            = var.global_settings.location
  resource_group_name = var.resource_group.name

  tags = var.global_settings.tags
}

# public IPs
resource "azurerm_public_ip" "cloudeng_lab_publicip" {
  name                = var.public_ip_name
  location            = var.global_settings.location
  resource_group_name = var.resource_group.name
  allocation_method   = "Dynamic"

  tags = var.global_settings.tags
}

# subnet
resource "azurerm_subnet" "cloudend_lab_subnet" {
  name                 = var.subnet_name
  resource_group_name  = var.resource_group.name
  virtual_network_name = azurerm_virtual_network.cloudeng_lab_vnetwork.name
  address_prefixes     = var.subnet_address_prefixes
}

# NSG and rule
resource "azurerm_network_security_group" "cloudeng_lab_nsg" {
  name                = "cloudeng_nsg"
  location            = var.global_settings.location
  resource_group_name = var.resource_group.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Jenkins"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  # security_rule {
  #   name                       = "Allow_WinRM"
  #   priority                   = 101
  #   direction                  = "Inbound"
  #   access                     = "Allow"
  #   protocol                   = "Tcp"
  #   source_port_range          = "*"
  #   destination_port_range     = "5985"
  #   source_address_prefix      = "*"
  #   destination_address_prefix = "*"
  # }

  tags = var.global_settings.tags
}

# NIC
resource "azurerm_network_interface" "cloudeng_lab_nic" {
  name                = var.nic.name
  location            = var.global_settings.location
  resource_group_name = var.resource_group.name

  ip_configuration {
    name                          = var.nic.nic_cfg_name
    subnet_id                     = azurerm_subnet.cloudend_lab_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.cloudeng_lab_publicip.id
  }

  tags = var.global_settings.tags
}

# NIC <> SG
resource "azurerm_network_interface_security_group_association" "cloudeng_lab_nic_sga" {
  network_interface_id      = azurerm_network_interface.cloudeng_lab_nic.id
  network_security_group_id = azurerm_network_security_group.cloudeng_lab_nsg.id
}
