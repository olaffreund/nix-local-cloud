let
  # The host system SSH key - using the actual generated public key
  host-key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIS7lm/CqkN7gEE02uHNVZMsYbRKKnv5srNjcwqtqmoP";

  # VM host keys - these will be used by VMs to decrypt secrets
  # You'll need to replace these with the actual public keys from your VMs
  # The keys can be extracted after first boot of each VM from /etc/ssh/ssh_host_ed25519_key.pub
  local-vm-key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIS7lm/CqkN7gEE02uHNVZMsYbRKKnv5srNjcwqtqmoP"; # Same as host for local VM testing
  aws-vm-key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIS7lm/CqkN7gEE02uHNVZMsYbRKKnv5srNjcwqtqmoP"; # Placeholder, replace with actual AWS VM key
  azure-vm-key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIS7lm/CqkN7gEE02uHNVZMsYbRKKnv5srNjcwqtqmoP"; # Placeholder, replace with actual Azure VM key
  gcp-vm-key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIS7lm/CqkN7gEE02uHNVZMsYbRKKnv5srNjcwqtqmoP"; # Placeholder, replace with actual GCP VM key
in {
  # Define the paths to the secrets
  "user-password.age".publicKeys = [
    host-key
    local-vm-key
    aws-vm-key
    azure-vm-key
    gcp-vm-key
  ];

  "database-password.age".publicKeys = [
    host-key
    local-vm-key
    aws-vm-key
    azure-vm-key
    gcp-vm-key
  ];

  "prometheus-password.age".publicKeys = [
    host-key
    local-vm-key
    aws-vm-key
    azure-vm-key
    gcp-vm-key
  ];

  "grafana-admin-password.age".publicKeys = [
    host-key
    local-vm-key
    aws-vm-key
    azure-vm-key
    gcp-vm-key
  ];

  "nginx-htpasswd.age".publicKeys = [
    host-key
    local-vm-key
    aws-vm-key
    azure-vm-key
    gcp-vm-key
  ];

  # Add entry for Tailscale auth key
  "tailscale-auth-key.age".publicKeys = [
    host-key
    local-vm-key
    aws-vm-key
    azure-vm-key
    gcp-vm-key
  ];
}
