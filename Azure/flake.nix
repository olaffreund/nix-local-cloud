{
  description = "NixOS Azure VM image builder and Terraform deployment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixos-generators,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    lib = nixpkgs.lib;

    # Function to get all NixOS modules from hosts subdirectories
    getHostModules = dir:
      if builtins.pathExists dir
      then let
        contents = builtins.readDir dir;
        subdirs = lib.filterAttrs (name: type: type == "directory") contents;
        getDefaultNix = name: dir + "/${name}/default.nix";
        hasDefaultNix = name: builtins.pathExists (getDefaultNix name);
        validServiceDirs = lib.attrNames (lib.filterAttrs (name: _: hasDefaultNix name) subdirs);
      in
        map (name: getDefaultNix name) validServiceDirs
      else [];

    # Import Common configuration from configuration.nix
    commonConfig = import ./configuration.nix { inherit lib pkgs; };

    # Azure-specific configuration
    azureConfig = {
      imports =
        [
          # Include all service modules from hosts/ directory
        ]
        ++ (getHostModules ../hosts);

      # Enable cloud-init for Azure
      services.cloud-init = {
        enable = true;
        settings = {
          cloud_init_modules = [
            "migrator"
            "seed_random"
            "bootcmd"
            "write-files"
            "growpart"
            "resizefs"
            "set_hostname"
            "update_hostname"
            "update_etc_hosts"
            "ca-certs"
            "users-groups"
            "ssh"
          ];

          cloud_config_modules = [
            "disk_setup"
            "mounts"
            "ssh-import-id"
            "set-passwords"
            "timezone"
            "runcmd"
            "ssh_authkey_fingerprints"
          ];
        };
      };

      # Setup waagent (Azure Linux Agent)
      services.udev.extraRules = ''
        SUBSYSTEM=="net", KERNEL=="eth*", ATTRS{address}=="00:15:5d:*", NAME="eth0"
      '';

      # Use grub boot loader for Azure compatibility
      boot.loader.grub = {
        enable = true;
        device = lib.mkForce "/dev/sda"; # Use mkForce to ensure this value is used over default
        efiSupport = lib.mkForce false;   # Use mkForce to match Azure image requirements
        efiInstallAsRemovable = lib.mkForce false; # Also set this to false to avoid conflicts
      };

      boot.loader.systemd-boot.enable = false;

      # Azure disk image configuration
      virtualisation.diskSize = 16384; # 16GB disk size
    };

    # Terraform module
    terraformModule = pkgs.writeTextFile {
      name = "terraform-deploy";
      text = ''
        #!/bin/sh
        set -e

        # Get directory of this script
        SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
        TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

        # Check if Azure image URI is provided
        if [ -z "$1" ]; then
          echo "Error: No image URI provided"
          echo "Usage: $0 <image-uri> [environment] [location]"
          exit 1
        fi

        IMAGE_URI="$1"
        ENVIRONMENT="''${2:-dev}"
        LOCATION="''${3:-eastus}"

        # Detect IP address
        MY_IP=$(curl -s https://checkip.amazonaws.com)

        echo "Deploying NixOS image $IMAGE_URI to $LOCATION ($ENVIRONMENT environment)"
        echo "Your IP for security group: $MY_IP"

        # Initialize Terraform if needed
        if [ ! -f "$TERRAFORM_DIR/.terraform/terraform.tfstate" ]; then
          echo "Initializing Terraform..."
          cd "$TERRAFORM_DIR" && terraform init
        fi

        # Run Terraform apply
        cd "$TERRAFORM_DIR" && terraform apply \
          -var="nixos_image_uri=$IMAGE_URI" \
          -var="environment=$ENVIRONMENT" \
          -var="location=$LOCATION" \
          -var="my_ip=$MY_IP" \
          -auto-approve

        echo "Deployment complete! Instance details:"
        cd "$TERRAFORM_DIR" && terraform output
      '';
      executable = true;
      destination = "/bin/terraform-deploy";
    };
  in {
    # Define packages that can be built
    packages.${system} = rec {
      # Default package is the Azure VHD
      default = azure-image;

      # Azure image builder
      azure-image = nixos-generators.nixosGenerate {
        inherit system;
        modules = [
          commonConfig
          azureConfig
        ];
        format = "azure";
      };

      # Terraform deploy script
      terraform-deploy = terraformModule;
    };

    # Define apps
    apps.${system} = {
      # Default app deploys to Azure
      default = self.apps.${system}.deploy-to-azure;

      # Deploy to Azure (requires image URI as argument)
      deploy-to-azure = {
        type = "app";
        program = "${self.packages.${system}.terraform-deploy}/bin/terraform-deploy";
      };
    };

    # Define a NixOS configuration for testing
    nixosConfigurations.azure-image = lib.nixosSystem {
      inherit system;
      modules = [
        commonConfig
        azureConfig
      ];
    };
  };
}
