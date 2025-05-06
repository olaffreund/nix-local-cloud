variable "location" {
  description = "Azure region to deploy resources"
  type        = string
  default     = "eastus"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vm_size" {
  description = "Azure VM size"
  type        = string
  default     = "Standard_B2s"  # 2 vCPU, 4 GiB - similar to local VM specs
}

variable "ssh_public_key" {
  description = "SSH public key to use for the instance"
  type        = string
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCMqMzUgRe2K350QBbQXbJFxVomsQbiIEw/ePUzjbyALklt5gMyo/yxbCWaKV1zeL4baR/vS5WOp9jytxceGFDaoJ7/O8yL4F2jj96Q5BKQOAz3NW/+Hmj/EemTOvVJWB1LQ+V7KgCbkxv6ZcUwL5a5+2QoujQNL5yVL3ZrIXv6LuKg8w8wykl57zDcJGgYsF+05oChswAmTFXI7hR5MdQgMGNM/eN78VZjSKJYGgeujoJg4BPQ6VE/qfIcJaPmuiiJBs0MDYIB8pKeSImXCDqYWEL6dZkSyro8HHHMAzFk1YP+pNIWVi8l3F+ajEFrEpTYKvdsZ4TiP/7CBaaI+0yVIq1mQ100AWeUiTn89iF8yqAgP8laLgMqZbM15Gm5UD7+g9/zsW0razyuclLogijvYRTMKt8vBa/rEfcx+qs8CuIrkXnD/KGfvoMDRgniWz8teaV1zfdDrkd6BhPVc5P3hI6gDY/xnSeijyyXL+XDE1ex6nfW5vNCwMiAWfDM+6k= olafkfreund@razer"
}

variable "my_ip" {
  description = "Your IP address for security group rules (use your current IP)"
  type        = string
  default     = "0.0.0.0"  # IMPORTANT: Replace with your actual IP for security
}

variable "nixos_username" {
  description = "Username for the NixOS VM"
  type        = string
  default     = "nixos"
}

variable "nixos_image_uri" {
  description = "URI to the VHD blob storage containing the NixOS image"
  type        = string
  # There is no default as this should be provided after building the custom image
}