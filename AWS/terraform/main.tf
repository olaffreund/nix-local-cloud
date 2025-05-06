terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.aws_region
}

locals {
  instance_name = "nixos-vm-${var.environment}"
}

# Security group for our NixOS VM
resource "aws_security_group" "nixos_vm_sg" {
  name        = "nixos-vm-sg-${var.environment}"
  description = "Security group for NixOS VM"

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32"]
    description = "SSH"
  }

  # HTTP access if Nginx is enabled
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP"
  }

  # HTTPS access
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS"
  }

  # Grafana access
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32"]
    description = "Grafana"
  }

  # PostgreSQL access
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32"]
    description = "PostgreSQL"
  }

  # Prometheus access
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32"]
    description = "Prometheus"
  }

  # Node Exporter access
  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32"]
    description = "Node Exporter"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "nixos-vm-sg-${var.environment}"
    Environment = var.environment
    Project     = "nixos-cloud"
  }
}

# Create SSH key pair
resource "aws_key_pair" "nixos_vm_key" {
  key_name   = "nixos-vm-key-${var.environment}"
  public_key = var.ssh_public_key
}

# Create EC2 instance using the custom AMI
resource "aws_instance" "nixos_vm" {
  ami                    = var.nixos_ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.nixos_vm_key.key_name
  vpc_security_group_ids = [aws_security_group.nixos_vm_sg.id]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name        = local.instance_name
    Environment = var.environment
    Project     = "nixos-cloud"
  }
}

# Elastic IP for the instance
resource "aws_eip" "nixos_vm_eip" {
  instance = aws_instance.nixos_vm.id
  domain   = "vpc"

  tags = {
    Name        = "nixos-vm-eip-${var.environment}"
    Environment = var.environment
    Project     = "nixos-cloud"
  }
}