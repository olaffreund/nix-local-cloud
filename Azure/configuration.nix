# NixOS configuration for Azure deployments
{pkgs, ...}: {
  # Import base configuration
  imports = [../common/base-configuration.nix];

  # Azure-specific settings
  networking.hostName = "nixos-azure";

  # Azure-specific utilities
  environment.systemPackages = with pkgs; [
    azure-cli
  ];
}
