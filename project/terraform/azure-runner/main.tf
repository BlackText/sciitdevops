# Declare the Azure region variable directly within the main.tf
variable "azure_region" {
  description = "Azure region for the infrastructure"
  type        = string
  default     = "East US"  # Change this to your desired region
}

# Provider configuration for Azure
provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "python-rg"
  location = var.azure_region
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "python-vnet"
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

# Subnet
resource "azurerm_subnet" "subnet" {
  name                 = "python-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.0/24"]
}

# Network Security Group for the Python instance
resource "azurerm_network_security_group" "python_sg" {
  name                = "python-security-group"
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                  = "Tcp"
    source_port_range         = "*"
    destination_port_range    = 22
    source_address_prefix     = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                  = "Tcp"
    source_port_range         = "*"
    destination_port_range    = 8080
    source_address_prefix     = "*"
    destination_address_prefix = "*"
  }
}

# Public IP for the Azure VM
resource "azurerm_public_ip" "python_ip" {
  name                = "python-ip"
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

# Network Interface
resource "azurerm_network_interface" "python_nic" {
  name                = "python-nic"
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.python_ip.id

    network_security_group_id     = azurerm_network_security_group.python_sg.id
  }
}

# Azure VM for Python setup
resource "azurerm_linux_virtual_machine" "python_vm" {
  name                = "python-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.azure_region
  size                = "Standard_B2ms"
  admin_username      = "azureuser"
  admin_ssh_key {
    username   = "azureuser"
    public_key = file("./azure.pub")  # Path to your public key
  }

  network_interface_ids = [
    azurerm_network_interface.python_nic.id,
  ]

  tags = {
    Name = "python-server"
  }

  # Install Python on the Azure VM using a custom script
  provisioner "remote-exec" {
    inline = [
      "sleep 60",  # Wait for 60 seconds to ensure the VM is initialized
      "sudo ufw disable",  # Disable UFW for testing purposes
      "sudo apt update -y",
      "sudo apt install -y python3 python3-pip",
      "sudo apt install -y python3-venv",
      "python3 --version",
      "sudo ufw allow 22",  # Ensure port 22 is allowed
      "sudo ufw allow 8080",  # Ensure port 8080 is open in UFW firewall
      "sudo ufw --force enable"
    ]

    connection {
      type        = "ssh"
      user        = "azureuser"
      private_key = file("./azure.pem")  # Path to your private key (make sure it's the private key for your 'azureuser')
      host        = azurerm_linux_virtual_machine.python_vm.public_ip_address
    }
  }
}

# Output Instance Public IP
output "python_vm_public_ip" {
  description = "Public IP of the Python server"
  value       = azurerm_linux_virtual_machine.python_vm.public_ip_address
}
