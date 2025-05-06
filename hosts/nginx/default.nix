{
  config,
  pkgs,
  lib,
  ...
}: {
  # Enable Nginx web server
  services.nginx = {
    enable = true;

    # Add recommended settings for security
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    # Configure a simple virtual host
    virtualHosts = {
      "localhost" = {
        default = true;
        locations = {
          "/" = {
            root = pkgs.writeTextDir "index.html" ''
              <!DOCTYPE html>
              <html>
                <head><title>Welcome to NixOS VM</title></head>
                <body>
                  <h1>Welcome to your NixOS VM!</h1>
                  <p>If you're seeing this, Nginx is working correctly.</p>
                  <p>You can replace this with your own content.</p>
                </body>
              </html>
            '';
          };

          # Add a proxy example for Grafana
          "/grafana/" = {
            proxyPass = "http://127.0.0.1:3000/";
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
            '';
          };
        };
      };
    };
  };

  # Open firewall port for HTTP
  networking.firewall.allowedTCPPorts = [80 443];

  # User message
  system.userActivation.nginxMessage = ''
    echo "Nginx is running at http://localhost"
  '';
}
