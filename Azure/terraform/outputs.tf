output "vm_id" {
  description = "ID of the Azure VM"
  value       = azurerm_linux_virtual_machine.nixos_vm.id
}

output "public_ip_address" {
  description = "Public IP address of the Azure VM"
  value       = azurerm_public_ip.nixos_public_ip.ip_address
}

output "ssh_connection" {
  description = "SSH connection command"
  value       = "ssh ${var.nixos_username}@${azurerm_public_ip.nixos_public_ip.ip_address}"
}

output "grafana_url" {
  description = "URL for Grafana dashboard"
  value       = "http://${azurerm_public_ip.nixos_public_ip.ip_address}:3000"
}

output "nginx_url" {
  description = "URL for Nginx web server"
  value       = "http://${azurerm_public_ip.nixos_public_ip.ip_address}"
}

output "prometheus_url" {
  description = "URL for Prometheus monitoring"
  value       = "http://${azurerm_public_ip.nixos_public_ip.ip_address}:9090"
}

output "postgresql_connection" {
  description = "PostgreSQL connection string"
  value       = "postgresql://nixos:nixos@${azurerm_public_ip.nixos_public_ip.ip_address}:5432/nixos"
}