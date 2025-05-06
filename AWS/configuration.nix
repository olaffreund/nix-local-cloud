# NixOS configuration for AWS deployments
{
  lib,
  pkgs,
  ...
}:
# Common configuration for AWS deployments
{
  # Basic system configuration
  system.stateVersion = "24.05";

  # Set hostname
  networking = {
    hostName = "nixos-aws";
    firewall = {
      enable = true;
      allowedTCPPorts = [22 80 443 3000 5432 9090 9100];
    };
  };

  # User configuration with SSH key
  users.users.nixos = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager"];
    hashedPassword = "$y$j9T$g3Yr4JPbMOV/O32XBRoQA0$ncnks6S0h4zA5gZlrO31J1n8WfK9TEDDOc.FHrqYaf5";
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCMqMzUgRe2K350QBbQXbJFxVomsQbiIEw/ePUzjbyALklt5gMyo/yxbCWaKV1zeL4baR/vS5WOp9jytxceGFDaoJ7/O8yL4F2jj96Q5BKQOAz3NW/+Hmj/EemTOvVJWB1LQ+V7KgCbkxv6ZcUwL5a5+2QoujQNL5yVL3ZrIXv6LuKg8w8wykl57zDcJGgYsF+05oChswAmTFXI7hR5MdQgMGNM/eN78VZjSKJYGgeujoJg4BPQ6VE/qfIcJaPmuiiJBs0MDYIB8pKeSImXCDqYWEL6dZkSyro8HHHMAzFk1YP+pNIWVi8l3F+ajEFrEpTYKvdsZ4TiP/7CBaaI+0yVIq1mQ100AWeUiTn89iF8yqAgP8laLgMqZbM15Gm5UD7+g9/zsW0razyuclLogijvYRTMKt8vBa/rEfcx+qs8CuIrkXnD/KGfvoMDRgniWz8teaV1zfdDrkd6BhPVc5P3hI6gDY/xnSeijyyXL+XDE1ex6nfW5vNCwMiAWfDM+6k= olafkfreund@razer"
    ];
  };

  # Allow passwordless sudo for wheel group
  security.sudo.wheelNeedsPassword = false;

  # SSH server configuration
  services.openssh = {
    enable = true;
    settings = {
      # Use mkForce to override the Amazon image default setting
      PermitRootLogin = lib.mkForce "no";
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = true;
    };
  };

  # Include useful packages
  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    git
    htop
    inetutils
    iproute2
    nettools
    # AWS-specific utilities
    awscli
  ];
}
