{...}: {
  # Enable the age service
  age.secrets = {
    # User password configuration
    user-password = {
      file = ./user-password.age;
      # Make this available to the users module
      mode = "0400";
      owner = "root";
    };

    # Database configurations
    database-password = {
      file = ./database-password.age;
      mode = "0400";
      owner = "postgres";
      group = "postgres";
    };

    # Prometheus configuration
    prometheus-password = {
      file = ./prometheus-password.age;
      mode = "0400";
      owner = "prometheus";
      group = "prometheus";
    };

    # Grafana configuration
    grafana-admin-password = {
      file = ./grafana-admin-password.age;
      mode = "0400";
      owner = "grafana";
      group = "grafana";
    };

    # Nginx configuration (for basic auth if needed)
    nginx-htpasswd = {
      file = ./nginx-htpasswd.age;
      mode = "0400";
      owner = "nginx";
      group = "nginx";
    };

    # Tailscale authentication key
    tailscale-auth-key = {
      file = ./tailscale-auth-key.age;
      mode = "0400";
      owner = "root";
    };
  };

  # Set the file to use as age identity
  # This is the path where NixOS stores the SSH host key that will be used to decrypt secrets
  age.identityPaths = [
    "/etc/ssh/ssh_host_ed25519_key"
  ];
}
