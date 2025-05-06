terraform {
  required_version = ">= 1.0.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# The Google Cloud VPC network
resource "google_compute_network" "nixos_network" {
  name                    = "nixos-network-${var.environment}"
  auto_create_subnetworks = false
  description             = "Network for NixOS deployment"
}

# The subnet for our instances
resource "google_compute_subnetwork" "nixos_subnet" {
  name          = "nixos-subnet-${var.environment}"
  ip_cidr_range = "10.0.1.0/24"
  network       = google_compute_network.nixos_network.id
  region        = var.region
}

# Firewall rule to allow SSH, HTTP/HTTPS and application traffic
resource "google_compute_firewall" "nixos_firewall" {
  name    = "nixos-firewall-${var.environment}"
  network = google_compute_network.nixos_network.name

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "3000", "5432", "9090", "9100"]
  }

  # Allow inbound traffic from specific IP (user's IP)
  source_ranges = ["${var.my_ip}/32"]
}

# The nixos VM instance
resource "google_compute_instance" "nixos_instance" {
  name         = "nixos-instance-${var.environment}"
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = var.nixos_image_name
      size  = 20  # Size in GB
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.nixos_subnet.name
    
    # This will create an ephemeral external IP
    access_config {}
  }

  # Add SSH key to the instance metadata
  metadata = {
    ssh-keys = "nixos:${file(var.ssh_public_key_file)}"
  }

  # Add startup script (if needed)
  metadata_startup_script = <<EOT
#!/bin/bash
echo "NixOS VM started on GCP"
  EOT

  # Service Account with minimal permissions required to communicate with GCP APIs
  service_account {
    scopes = [
      "https://www.googleapis.com/auth/compute.readonly",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write"
    ]
  }

  # Labels for the instance
  labels = {
    environment = var.environment
    managed-by  = "terraform"
    name        = "nixos-instance"
  }

  # Ensure the instance is deleted before the network is destroyed
  depends_on = [
    google_compute_subnetwork.nixos_subnet
  ]
}