# NixOS configuration for AWS deployments
{pkgs, ...}: {
  # Import base configuration
  imports = [../common/base-configuration.nix];

  # AWS-specific settings
  networking.hostName = "nixos-aws";

  # AWS-specific utilities
  environment.systemPackages = with pkgs; [
    awscli
  ];
}
