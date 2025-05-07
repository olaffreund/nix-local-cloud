{
  config,
  pkgs,
  ...
}: {
  # Enable the Tailscale service
  services.tailscale = {
    enable = true;

    # Use the stable release of Tailscale
    package = pkgs.tailscale;

    # Enable subnet routing and exit node capabilities
    useRoutingFeatures = "both";

    # Automatically open firewall ports for Tailscale
    openFirewall = true;

    # Configure Tailscale to authenticate automatically using the auth key
    authKeyFile = config.age.secrets.tailscale-auth-key.path;

    # Auto-connect to Tailscale network on system start
    autoConnect = {
      enable = true;
      extraArgs = [
        "--accept-routes"
        "--accept-dns"
      ];
    };
  };

  # Enable IP forwarding for Tailscale to work as a subnet router or exit node
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  # Install tailscale CLI tools
  environment.systemPackages = with pkgs; [
    tailscale
  ];

  # Add descriptive message to login info about Tailscale
  environment.etc."issue.d/tailscale-info.txt".text = ''
    Tailscale is enabled on this machine.
    To check status: tailscale status
    To disable: tailscale down
  '';
}
