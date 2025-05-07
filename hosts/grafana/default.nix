{config, ...}: {
  # Enable Grafana service
  services.grafana = {
    enable = true;

    # Updated configuration using the new settings API
    settings = {
      server = {
        http_port = 3000;
        domain = "localhost";
        http_addr = "0.0.0.0";
      };

      security = {
        # Use secure password from agenix
        admin_password = "$__file{${config.age.secrets.grafana-admin-password.path}}";
      };

      # Fix for deprecated anonymous auth options
      "auth.anonymous" = {
        enabled = true;
        org_name = "Development";
        org_role = "Viewer";
      };
    };

    # Provision some default dashboards
    provision = {
      enable = true;
      # Updated datasources configuration
      datasources = {
        settings = {
          apiVersion = 1;
          datasources = [
            {
              name = "Prometheus";
              type = "prometheus";
              access = "proxy";
              url = "http://localhost:9090";
              isDefault = true;
            }
          ];
        };
      };
    };
  };

  # Open firewall port for Grafana
  networking.firewall.allowedTCPPorts = [3000];

  # Add a custom message to the login banner
  environment.etc."issue.d/grafana-info.txt".text = ''
    Grafana is running at http://localhost:3000
    Default credentials: admin/[secure-password]
  '';
}
