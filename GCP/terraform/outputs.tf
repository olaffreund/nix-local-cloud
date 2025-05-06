output "instance_name" {
  description = "Name of the NixOS VM instance"
  value       = google_compute_instance.nixos_instance.name
}

output "instance_id" {
  description = "ID of the NixOS VM instance"
  value       = google_compute_instance.nixos_instance.id
}

output "public_ip" {
  description = "Public IP address of the NixOS VM instance"
  value       = google_compute_instance.nixos_instance.network_interface[0].access_config[0].nat_ip
}

output "ssh_command" {
  description = "Command to SSH into the NixOS VM instance"
  value       = "ssh nixos@${google_compute_instance.nixos_instance.network_interface[0].access_config[0].nat_ip}"
}

output "network_name" {
  description = "Name of the VPC network created for NixOS"
  value       = google_compute_network.nixos_network.name
}

output "connection_info" {
  description = "Connection information"
  value       = <<-EOT
    Instance Name: ${google_compute_instance.nixos_instance.name}
    External IP: ${google_compute_instance.nixos_instance.network_interface[0].access_config[0].nat_ip}
    Zone: ${google_compute_instance.nixos_instance.zone}
    Project: ${var.project_id}
    
    Connect using: ssh nixos@${google_compute_instance.nixos_instance.network_interface[0].access_config[0].nat_ip}
  EOT
}