{
  description = "NixOS GCP compute image builder and Terraform deployment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixos-generators,
    agenix,
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

    # Import common configuration from configuration.nix
    commonConfig = import ./configuration.nix {inherit lib pkgs;};

    # GCP-specific configuration
    gcpConfig = {
      imports =
        [
          # Include all service modules from hosts/ directory
        ]
        ++ (getHostModules ../hosts);

      # GCP-specific configuration

      # Enable cloud-init for GCP
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

      # Google Compute Engine settings
      boot.kernelParams = ["console=ttyS0" "panic=1" "boot.panic_on_fail"];

      # Use grub boot loader for GCP compatibility
      boot.loader.grub = {
        enable = true;
        device = lib.mkForce "nodev";
        efiSupport = false;
        forceInstall = true;
        extraConfig = ''
          serial --unit=0 --speed=38400
          terminal_input serial
          terminal_output serial
        '';
      };

      boot.loader.systemd-boot.enable = false;

      # GCP disk image configuration
      virtualisation.diskSize = 16384; # 16 GB disk image size
      virtualisation.googleComputeImage.compressionLevel = 9;
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

        # Check if GCP image name is provided
        if [ -z "$1" ]; then
          echo "Error: No image name provided"
          echo "Usage: $0 <image-name> [project-id] [zone]"
          exit 1
        fi

        IMAGE_NAME="$1"
        PROJECT_ID="''${2:-$(gcloud config get-value project)}"
        ZONE="''${3:-us-central1-a}"

        # Detect IP address
        MY_IP=$(curl -s https://checkip.amazonaws.com)

        echo "Deploying NixOS image $IMAGE_NAME to GCP project $PROJECT_ID in zone $ZONE"
        echo "Your IP for firewall rule: $MY_IP"

        # Initialize Terraform if needed
        if [ ! -f "$TERRAFORM_DIR/.terraform/terraform.tfstate" ]; then
          echo "Initializing Terraform..."
          cd "$TERRAFORM_DIR" && terraform init
        fi

        # Run Terraform apply
        cd "$TERRAFORM_DIR" && terraform apply \
          -var="nixos_image_name=$IMAGE_NAME" \
          -var="project_id=$PROJECT_ID" \
          -var="zone=$ZONE" \
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
      # Default package is the GCP disk image
      default = gcp-image;

      # GCP image builder
      gcp-image = nixos-generators.nixosGenerate {
        inherit system;
        modules = [
          commonConfig
          gcpConfig
          # Add agenix module
          agenix.nixosModules.default
          ../secrets/secrets.nix
        ];
        format = "gce";
      };

      # Terraform deploy script
      terraform-deploy = terraformModule;
    };

    # Define apps
    apps.${system} = {
      # Default app deploys to GCP
      default = self.apps.${system}.deploy-to-gcp;

      # Deploy to GCP (requires image name as argument)
      deploy-to-gcp = {
        type = "app";
        program = "${self.packages.${system}.terraform-deploy}/bin/terraform-deploy";
      };
    };

    # Define a NixOS configuration for testing
    nixosConfigurations.gcp-image = lib.nixosSystem {
      inherit system;
      modules = [
        commonConfig
        gcpConfig
        # Add agenix module
        agenix.nixosModules.default
        ../secrets/secrets.nix
      ];
    };
  };
}
