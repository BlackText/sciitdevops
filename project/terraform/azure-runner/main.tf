
variable "location" {
  description = "Azure region for the infrastructure"
  type        = string
  default     = "East US"
}

resource "azurerm_resource_group" "rg2" {
  name     = "python-rg2-new"  # Change this name
  location = var.location
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "python-vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg2.name
  address_space       = ["10.0.0.0/16"]
}

# Subnets
resource "azurerm_subnet" "public_subnet" {
  name                 = "public-subnet"
  resource_group_name  = azurerm_resource_group.rg2.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.3.0/24"]
}

# Network Security Group
resource "azurerm_network_security_group" "nsg" {
  name                = "python-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg2.name
}

resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  subnet_id                 = azurerm_subnet.public_subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Security rules
resource "azurerm_network_security_rule" "allow_ssh" {
  name                        = "Allow-SSH"
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg2.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_security_rule" "allow_http" {
  name                        = "Allow-HTTP"
  priority                    = 1002
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8080"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg2.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

# Network Interface
resource "azurerm_network_interface" "nic" {
  name                = "python-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg2.name

  ip_configuration {
    name                          = "public-ip"
    subnet_id                     = azurerm_subnet.public_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ip.id
  }
}

# Public IP
resource "azurerm_public_ip" "ip" {
  name                = "python-public-ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg2.name
  allocation_method   = "Static"  # <-- Change this from Dynamic to Static
  sku                = "Standard"  # Explicitly define SKU
}

# Linux Virtual Machine
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "python-vm"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg2.name
  size               = "Standard_B2s"
  admin_username      = "azureuser"

  network_interface_ids = [azurerm_network_interface.nic.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("./azure.pem.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(<<EOF
#!/bin/bash
sleep 60
sudo apt update -y
sudo apt install -y python3 python3-pip
sudo apt install -y python3-venv
python3 --version
EOF
  )
}

# Output VM Public IP
output "vm_public_ip" {
  description = "Public IP of the Python VM"
  value       = azurerm_public_ip.ip.ip_address
}


