# Azure Terraform configuration for NixOS deployment

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.85.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

# Variables
variable "resource_group_name" {
  description = "Name of the resource group"
  default     = "nixos-azure-rg"
}

variable "location" {
  description = "Azure region"
  default     = "westeurope"
}

variable "vm_name" {
  description = "Name of the VM"
  default     = "nixos-azure-vm"
}

variable "vm_size" {
  description = "Size of the VM"
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Admin username"
  default     = "admin"
}

variable "image_name" {
  description = "Name of the NixOS image"
  default     = "nixos-image"
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "nixos-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Subnet
resource "azurerm_subnet" "subnet" {
  name                 = "nixos-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Public IP
resource "azurerm_public_ip" "public_ip" {
  name                = "nixos-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

# Network Security Group
resource "azurerm_network_security_group" "nsg" {
  name                = "nixos-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # Allow SSH
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

  # Allow HTTP
  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow HTTPS
  security_rule {
    name                       = "HTTPS"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Network Interface
resource "azurerm_network_interface" "nic" {
  name                = "nixos-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "nic_nsg_association" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Reference to the custom NixOS image
data "azurerm_image" "nixos_image" {
  name                = var.image_name
  resource_group_name = azurerm_resource_group.rg.name
  
  # Uncomment this if you want to create the VM and image in separate steps
  # depends_on = [
  #   null_resource.image_dependency
  # ]
}

# Virtual Machine
resource "azurerm_linux_virtual_machine" "vm" {
  name                = var.vm_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  # Use SSH key authentication
  admin_ssh_key {
    username   = var.admin_username
    # Replace with your SSH public key path or actual key
    public_key = file("~/.ssh/id_rsa.pub")
  }

  # Boot diagnostics
  boot_diagnostics {
    storage_account_uri = null
  }
  
  # Use the custom NixOS image
  source_image_id = data.azurerm_image.nixos_image.id

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 64
  }
}

# Output the public IP
output "public_ip_address" {
  value = azurerm_public_ip.public_ip.ip_address
  description = "The public IP address of the NixOS VM"
  depends_on = [azurerm_linux_virtual_machine.vm]
}

# Optional resource to handle the image creation dependency
# Uncomment and modify if you need to manage the image creation separately
# resource "null_resource" "image_dependency" {
#   provisioner "local-exec" {
#     command = "echo 'Ensuring the image ${var.image_name} is created first'"
#   }
# }