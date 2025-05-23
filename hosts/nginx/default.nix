{
  config,
  pkgs,
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

          # Add a secure admin area with basic auth using agenix
          "/admin/" = {
            root = pkgs.writeTextDir "admin/index.html" ''
              <!DOCTYPE html>
              <html>
                <head><title>Admin Area</title></head>
                <body>
                  <h1>Secure Admin Area</h1>
                  <p>This area is protected with basic authentication.</p>
                </body>
              </html>
            '';
            extraConfig = ''
              auth_basic "Administrator's Area";
              auth_basic_user_file ${config.age.secrets.nginx-htpasswd.path};
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

  # Add a custom message to the login banner
  environment.etc."issue.d/nginx-info.txt".text = ''
    Nginx is running at http://localhost
    Admin area at http://localhost/admin/ (credentials: admin/[secure-password])
  '';
}
