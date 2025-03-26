variable "AZURE_SUBSCRIPTION_ID" {
  description = "Azure Subscription ID"
  type        = string
}

variable "AZURE_CLIENT_ID" {
  description = "Azure Client ID"
  type        = string
}

variable "AZURE_CLIENT_SECRET" {
  description = "Azure Client Secret"
  type        = string
  sensitive   = true
}

variable "AZURE_TENANT_ID" {
  description = "Azure Tenant ID"
  type        = string
}

provider "azurerm" {
  features {}
  subscription_id = var.AZURE_SUBSCRIPTION_ID
  client_id       = var.AZURE_CLIENT_ID
  client_secret   = var.AZURE_CLIENT_SECRET
  tenant_id       = var.AZURE_TENANT_ID
}

# Resource Group
resource "azurerm_resource_group" "test" {
  name     = "test-new"
  location = "East US"
}

# Virtual Network
resource "azurerm_virtual_network" "test_vnet" {
  name                = "test-vnet"
  location            = azurerm_resource_group.test.location
  resource_group_name = azurerm_resource_group.test.name
  address_space       = ["10.0.0.0/16"]
}

# Subnet
resource "azurerm_subnet" "test_subnet" {
  name                 = "test-subnet"
  resource_group_name  = azurerm_resource_group.test.name
  virtual_network_name = azurerm_virtual_network.test_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Network Security Group
resource "azurerm_network_security_group" "test_nsg" {
  name                = "test-nsg"
  location            = azurerm_resource_group.test.location
  resource_group_name = azurerm_resource_group.test.name
}

resource "azurerm_network_security_rule" "allow_ssh" {
  name                        = "allow-ssh"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.test.name
  network_security_group_name = azurerm_network_security_group.test_nsg.name
}

# Public IP
resource "azurerm_public_ip" "test_pip" {
  name                = "test-public-ip"
  location            = azurerm_resource_group.test.location
  resource_group_name = azurerm_resource_group.test.name
  allocation_method   = "Static"
}

# Network Interface
resource "azurerm_network_interface" "test_nic" {
  name                = "test-nic"
  location            = azurerm_resource_group.test.location
  resource_group_name = azurerm_resource_group.test.name

  ip_configuration {
    name                          = "test-ip"
    subnet_id                     = azurerm_subnet.test_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.test_pip.id
  }
}

# Associate NSG with NIC
resource "azurerm_network_interface_security_group_association" "test_nic_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.test_nic.id
  network_security_group_id = azurerm_network_security_group.test_nsg.id
}
resource "azurerm_linux_virtual_machine" "test_vm" {
  name                = "test-vm"
  resource_group_name = azurerm_resource_group.test.name
  location            = azurerm_resource_group.test.location
  size                = "Standard_B2ms"
  admin_username      = "azureuser"
  network_interface_ids = [azurerm_network_interface.test_nic.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("./azure.pem.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 100
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # # Provisioner to run the Ansible playbook
  # provisioner "local-exec" {
  #   command = "sleep 90 && ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i ${azurerm_public_ip.test_pip.ip_address}, -u azureuser --private-key=~/.ssh/id_rsa install_k3s.yml -vv"
  # }

  tags = {
    Name = "test-vm"
  }
}

# Output Public IP
output "test_vm_public_ip" {
  description = "Public IP of the test VM"
  value       = azurerm_public_ip.test_pip.ip_address
}

resource "null_resource" "ansible_playbook" {
  depends_on = [azurerm_linux_virtual_machine.test_vm]

  provisioner "local-exec" {
    command = "sleep 90 && ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i ${azurerm_public_ip.test_pip.ip_address}, -u azureuser --private-key=./azure.pem install_k3s.yml -vv"
  }
}
