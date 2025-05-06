terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.2.0"
}

provider "azurerm" {
  features {
    virtual_machine {
      # Allow deletion of VM even if disk is attached
      delete_os_disk_on_deletion = true
    }
  }
}

locals {
  resource_prefix = "nixos-vm-${var.environment}"
}

# Resource group
resource "azurerm_resource_group" "nixos_rg" {
  name     = "${local.resource_prefix}-rg"
  location = var.location
  
  tags = {
    Environment = var.environment
    Project     = "nixos-cloud"
  }
}

# Virtual network
resource "azurerm_virtual_network" "nixos_vnet" {
  name                = "${local.resource_prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.nixos_rg.location
  resource_group_name = azurerm_resource_group.nixos_rg.name
  
  tags = {
    Environment = var.environment
    Project     = "nixos-cloud"
  }
}

# Subnet
resource "azurerm_subnet" "nixos_subnet" {
  name                 = "${local.resource_prefix}-subnet"
  resource_group_name  = azurerm_resource_group.nixos_rg.name
  virtual_network_name = azurerm_virtual_network.nixos_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Public IP address
resource "azurerm_public_ip" "nixos_public_ip" {
  name                = "${local.resource_prefix}-pip"
  resource_group_name = azurerm_resource_group.nixos_rg.name
  location            = azurerm_resource_group.nixos_rg.location
  allocation_method   = "Static"
  
  tags = {
    Environment = var.environment
    Project     = "nixos-cloud"
  }
}

# Network security group
resource "azurerm_network_security_group" "nixos_nsg" {
  name                = "${local.resource_prefix}-nsg"
  location            = azurerm_resource_group.nixos_rg.location
  resource_group_name = azurerm_resource_group.nixos_rg.name
  
  # SSH access
  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "${var.my_ip}/32"
    destination_address_prefix = "*"
  }
  
  # HTTP access
  security_rule {
    name                       = "HTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  # HTTPS access
  security_rule {
    name                       = "HTTPS"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  # Grafana access
  security_rule {
    name                       = "Grafana"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefix      = "${var.my_ip}/32"
    destination_address_prefix = "*"
  }
  
  # PostgreSQL access
  security_rule {
    name                       = "PostgreSQL"
    priority                   = 140
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = "${var.my_ip}/32"
    destination_address_prefix = "*"
  }
  
  # Prometheus access
  security_rule {
    name                       = "Prometheus"
    priority                   = 150
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9090"
    source_address_prefix      = "${var.my_ip}/32"
    destination_address_prefix = "*"
  }
  
  # Node Exporter access
  security_rule {
    name                       = "NodeExporter"
    priority                   = 160
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9100"
    source_address_prefix      = "${var.my_ip}/32"
    destination_address_prefix = "*"
  }
  
  tags = {
    Environment = var.environment
    Project     = "nixos-cloud"
  }
}

# Network interface
resource "azurerm_network_interface" "nixos_nic" {
  name                = "${local.resource_prefix}-nic"
  location            = azurerm_resource_group.nixos_rg.location
  resource_group_name = azurerm_resource_group.nixos_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.nixos_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.nixos_public_ip.id
  }
  
  tags = {
    Environment = var.environment
    Project     = "nixos-cloud"
  }
}

# Associate NSG with network interface
resource "azurerm_network_interface_security_group_association" "nixos_nic_nsg_association" {
  network_interface_id      = azurerm_network_interface.nixos_nic.id
  network_security_group_id = azurerm_network_security_group.nixos_nsg.id
}

# Image reference from URI if using custom image
resource "azurerm_image" "nixos_image" {
  name                = "${local.resource_prefix}-image"
  location            = azurerm_resource_group.nixos_rg.location
  resource_group_name = azurerm_resource_group.nixos_rg.name
  
  os_disk {
    os_type     = "Linux"
    os_state    = "Generalized"
    blob_uri    = var.nixos_image_uri
    size_gb     = 16
    storage_type = "Standard_LRS"
  }
  
  tags = {
    Environment = var.environment
    Project     = "nixos-cloud"
  }
}

# Virtual machine
resource "azurerm_linux_virtual_machine" "nixos_vm" {
  name                  = "${local.resource_prefix}"
  location              = azurerm_resource_group.nixos_rg.location
  resource_group_name   = azurerm_resource_group.nixos_rg.name
  network_interface_ids = [azurerm_network_interface.nixos_nic.id]
  size                  = var.vm_size
  
  os_disk {
    name                 = "${local.resource_prefix}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  
  # Use custom image
  source_image_id = azurerm_image.nixos_image.id
  
  # Use marketplace image (alternative to custom image)
  # source_image_reference {
  #   publisher = "canonical"
  #   offer     = "0001-com-ubuntu-server-jammy"
  #   sku       = "22_04-lts"
  #   version   = "latest"
  # }
  
  admin_username = var.nixos_username
  
  # Use SSH key for authentication
  admin_ssh_key {
    username   = var.nixos_username
    public_key = var.ssh_public_key
  }

  # Disable password authentication
  disable_password_authentication = true
  
  tags = {
    Environment = var.environment
    Project     = "nixos-cloud"
  }
}