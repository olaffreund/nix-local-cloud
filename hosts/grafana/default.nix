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

    # Basic authentication
    security = {
      adminUser = "admin";
      adminPasswordFile = "${pkgs.writeText "adminpass" "admin"}";
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
      datasources = {
        enable = true;
        path = "${pkgs.writeText "datasources.yaml" ''
          apiVersion: 1
          datasources:
            - name: Prometheus
              type: prometheus
              access: proxy
              url: http://localhost:9090
              isDefault: true
        ''}";
      };
    };
  };

  # Open firewall port for Grafana
  networking.firewall.allowedTCPPorts = [3000];

  # User message
  system.userActivation.grafanaMessage = ''
    echo "Grafana is running at http://localhost:3000"
    echo "Default credentials: admin/admin"
  '';
}
