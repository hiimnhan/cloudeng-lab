resource "azurerm_resource_group" "cloudeng_lab" {
  name     = var.global_settings.resource_group_name
  location = var.global_settings.location

  tags = var.global_settings.tags
}

# virtual network
resource "azurerm_virtual_network" "cloudeng_lab_vnetwork" {
  name                = "cloudeng_network"
  address_space       = ["10.0.0.0/16"]
  location            = var.global_settings.location
  resource_group_name = azurerm_resource_group.cloudeng_lab.name

  tags = var.global_settings.tags
}

# public IPs
resource "azurerm_public_ip" "cloudeng_lab_publicip" {
  name                = "cloudeng_publicip"
  location            = var.global_settings.location
  resource_group_name = azurerm_resource_group.cloudeng_lab.name
  allocation_method   = "Dynamic"

  tags = var.global_settings.tags
}

# subnet
resource "azurerm_subnet" "cloudend_lab_subnet" {
  name                 = "cloudeng_subnet"
  resource_group_name  = azurerm_resource_group.cloudeng_lab.name
  virtual_network_name = azurerm_virtual_network.cloudeng_lab_vnetwork.name
  address_prefixes     = ["10.0.1.0/24"]
}

# NSG and rule
resource "azurerm_network_security_group" "cloudeng_lab_nsg" {
  name                = "cloudeng_nsg"
  location            = var.global_settings.location
  resource_group_name = azurerm_resource_group.cloudeng_lab.name

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

  tags = var.global_settings.tags
}

# NIC
resource "azurerm_network_interface" "cloudeng_lab_nic" {
  name                = "cloudeng_nic"
  location            = var.global_settings.location
  resource_group_name = azurerm_resource_group.cloudeng_lab.name

  ip_configuration {
    name                          = "cloudeng_nic_config"
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
