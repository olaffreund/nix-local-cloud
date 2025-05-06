{
  config,
  pkgs,
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
