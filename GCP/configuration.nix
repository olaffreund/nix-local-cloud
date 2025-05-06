# NixOS configuration for GCP deployments
{pkgs, ...}: {
  # Import base configuration
  imports = [../common/base-configuration.nix];

  # GCP-specific settings
  networking.hostName = "nixos-gcp";

  # GCP-specific utilities
  environment.systemPackages = with pkgs; [
    google-cloud-sdk
  ];
}
