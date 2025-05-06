variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region to deploy to"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The GCP zone to deploy to"
  type        = string
  default     = "us-central1-a"
}

variable "environment" {
  description = "The deployment environment (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "nixos_image_name" {
  description = "The name of the NixOS GCP image to deploy"
  type        = string
}

variable "machine_type" {
  description = "The GCP machine type for the VM instance"
  type        = string
  default     = "e2-medium"
}

variable "my_ip" {
  description = "Your current public IP address for firewall rules"
  type        = string
}

variable "ssh_public_key_file" {
  description = "Path to the SSH public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}