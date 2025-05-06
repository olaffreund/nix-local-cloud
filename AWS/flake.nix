{
  description = "NixOS AWS AMI builder and Terraform deployment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-generators, ... }:
    let
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

      # Common configuration for both local and AWS deployments
      commonConfig = {
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
      };

      # AWS-specific configuration
      awsConfig = {
        imports = [
          # Include all service modules from hosts/ directory
        ] ++ (getHostModules ../hosts);

        # AWS-specific configuration
        ec2.hvm = true;
        ec2.efi = true;
        
        # Enable cloud-init for AWS
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
              "disable-ec2-metadata"
              "runcmd"
              "ssh_authkey_fingerprints"
            ];
          };
        };
        
        # Use grub boot loader for better AWS compatibility
        boot.loader.grub = {
          enable = true;
          device = "nodev";
          efiSupport = true;
          efiInstallAsRemovable = true;
        };
        
        boot.loader.systemd-boot.enable = false;
        
        # Updated disk size configuration using the new option name
        virtualisation.diskSize = 16384; # 16 GB disk image size
        
        # Keep format under amazonImage
        amazonImage = {
          format = "raw";
        };
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
          
          # Check if AWS AMI ID is provided
          if [ -z "$1" ]; then
            echo "Error: No AMI ID provided"
            echo "Usage: $0 <ami-id> [environment] [region]"
            exit 1
          fi
          
          AMI_ID="$1"
          ENVIRONMENT="''${2:-dev}"
          REGION="''${3:-us-west-2}"
          
          # Detect IP address
          MY_IP=$(curl -s https://checkip.amazonaws.com)
          
          echo "Deploying NixOS AMI $AMI_ID to $REGION ($ENVIRONMENT environment)"
          echo "Your IP for security group: $MY_IP"
          
          # Initialize Terraform if needed
          if [ ! -f "$TERRAFORM_DIR/.terraform/terraform.tfstate" ]; then
            echo "Initializing Terraform..."
            cd "$TERRAFORM_DIR" && terraform init
          fi
          
          # Run Terraform apply
          cd "$TERRAFORM_DIR" && terraform apply \
            -var="nixos_ami_id=$AMI_ID" \
            -var="environment=$ENVIRONMENT" \
            -var="aws_region=$REGION" \
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
        # Default package is the AWS AMI
        default = aws-ami;

        # AWS AMI builder
        aws-ami = nixos-generators.nixosGenerate {
          inherit system;
          modules = [
            commonConfig
            awsConfig
          ];
          format = "amazon";
        };
        
        # Terraform deploy script
        terraform-deploy = terraformModule;
      };
      
      # Define apps
      apps.${system} = {
        # Default app deploys to AWS
        default = self.apps.${system}.deploy-to-aws;
        
        # Deploy to AWS (requires AMI ID as argument)
        deploy-to-aws = {
          type = "app";
          program = "${self.packages.${system}.terraform-deploy}/bin/terraform-deploy";
        };
      };
      
      # Define a NixOS configuration for testing
      nixosConfigurations.aws-image = lib.nixosSystem {
        inherit system;
        modules = [
          commonConfig
          awsConfig
        ];
      };
    };
}