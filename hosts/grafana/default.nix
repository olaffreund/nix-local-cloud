{
  config,
  pkgs,
  lib,
  ...
}: {
  # Enable Grafana service
  services.grafana = {
    enable = true;
    port = 3000;
    domain = "localhost";
    addr = "0.0.0.0";

    # Updated configuration using the new settings API
    settings = {
      security = {
        # Set admin password directly (for development only)
        admin_password = "admin";
        # Alternatively, use this for production:
        # admin_password = "$__file{${pkgs.writeText "admin-password" "admin"}}";
      };
      
      server = {
        # Ensure server settings are consistent
        http_port = 3000;
        domain = "localhost";
        http_addr = "0.0.0.0";
      };
    };

    # Enable anonymous access for development
    auth.anonymous = {
      enable = true;
      org_name = "Development";
      org_role = "Viewer";
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
    Default credentials: admin/admin
  '';
}
