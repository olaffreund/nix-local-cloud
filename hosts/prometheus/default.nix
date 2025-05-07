{
  pkgs,
  config,
  lib,
  ...
}: {
  # Enable Prometheus monitoring system
  services.prometheus = {
    enable = true;
    port = 9090;

    # Basic configuration
    globalConfig = {
      scrape_interval = "15s";
      evaluation_interval = "15s";
    };

    # External URL without trying to read the secret during evaluation
    webExternalUrl = "http://localhost:9090";

    # Configure rules for alerts
    ruleFiles = [
      (pkgs.writeText "prometheus-rules.yml" ''
        groups:
        - name: example
          rules:
          - record: job:http_requests:rate1m
            expr: sum by (job) (rate(http_requests_total[1m]))
      '')
    ];

    # Configure scrape targets
    scrapeConfigs = [
      {
        job_name = "prometheus";
        static_configs = [
          {
            targets = ["localhost:9090"];
            labels = {instance = "prometheus";};
          }
        ];
      }
      {
        job_name = "node";
        static_configs = [
          {
            targets = ["localhost:9100"];
            labels = {instance = "node";};
          }
        ];
      }
      # Add more scrape targets as needed
    ];
  };

  # Create a systemd service override to handle authentication securely
  systemd.services.prometheus = {
    preStart = lib.mkBefore ''
      # Create web config with the password from the age secret
      PROMETHEUS_PASSWORD=$(cat ${config.age.secrets.prometheus-password.path})

      # Use htpasswd to create the proper bcrypt hash
      HASHED_PASSWORD=$(echo "$PROMETHEUS_PASSWORD" | ${pkgs.apacheHttpd}/bin/htpasswd -niBC 10 admin)

      # Write the web config file
      cat > /run/prometheus-web-config.yml <<EOF
      basic_auth_users:
        admin: $(echo "$HASHED_PASSWORD" | cut -d: -f2)
      EOF
    '';

    # Make sure the web config file is included in the service command line
    serviceConfig = {
      # Add the web config file to the Prometheus command line arguments
      ExecStart = lib.mkForce ''
        ${config.services.prometheus.package}/bin/prometheus \
          --web.config.file=/run/prometheus-web-config.yml \
          --storage.tsdb.path=${config.services.prometheus.stateDir}/data \
          --web.listen-address=:${toString config.services.prometheus.port} \
          --web.external-url=${config.services.prometheus.webExternalUrl} \
          ${lib.concatMapStringsSep " \\\n  " (x: "--web.enable-lifecycle=${x}") [(lib.boolToString config.services.prometheus.enableReload)]}
      '';
    };
  };

  # Also enable node exporter for host metrics
  services.prometheus.exporters = {
    node = {
      enable = true;
      enabledCollectors = ["systemd"];
      port = 9100;
    };
  };

  # Open firewall ports for Prometheus and node exporter
  networking.firewall.allowedTCPPorts = [9090 9100];

  # Add a custom message to the login banner
  environment.etc."issue.d/prometheus-info.txt".text = ''
    Prometheus is running at http://localhost:9090
    Node Exporter is running at http://localhost:9100/metrics
  '';
}
