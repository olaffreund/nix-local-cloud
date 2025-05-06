output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.nixos_vm.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_eip.nixos_vm_eip.public_ip
}

output "ssh_connection" {
  description = "SSH connection command"
  value       = "ssh ${var.nixos_username}@${aws_eip.nixos_vm_eip.public_ip}"
}

output "grafana_url" {
  description = "URL for Grafana dashboard"
  value       = "http://${aws_eip.nixos_vm_eip.public_ip}:3000"
}

output "nginx_url" {
  description = "URL for Nginx web server"
  value       = "http://${aws_eip.nixos_vm_eip.public_ip}"
}

output "prometheus_url" {
  description = "URL for Prometheus monitoring"
  value       = "http://${aws_eip.nixos_vm_eip.public_ip}:9090"
}

output "postgresql_connection" {
  description = "PostgreSQL connection string"
  value       = "postgresql://nixos:nixos@${aws_eip.nixos_vm_eip.public_ip}:5432/nixos"
}