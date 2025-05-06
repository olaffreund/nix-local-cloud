{
  description = "NixOS + Terraform AWS/Azure Deployment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    microvm = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    nixos-generators,
    microvm,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {inherit system;};
    pkgs-unstable = import nixpkgs-unstable {inherit system;};

    # Common configuration shared between all deployments
    commonConfig = {
      config,
      lib,
      pkgs,
      modulesPath,
      ...
    }: {
      imports = [
        "${modulesPath}/virtualisation/amazon-image.nix"
      ];

      # System configuration
      system.stateVersion = "24.11";

      # User configuration
      users.users.admin = {
        isNormalUser = true;
        extraGroups = ["wheel"];
        initialPassword = "changeme";
        openssh.authorizedKeys.keys = [
          # Add your SSH public key here
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCMqMzUgRe2K350QBbQXbJFxVomsQbiIEw/ePUzjbyALklt5gMyo/yxbCWaKV1zeL4baR/vS5WOp9jytxceGFDaoJ7/O8yL4F2jj96Q5BKQOAz3NW/+Hmj/EemTOvVJWB1LQ+V7KgCbkxv6ZcUwL5a5+2QoujQNL5yVL
       3ZrIXv6LuKg8w8wykl57zDcJGgYsF+05oChswAmTFXI7hR5MdQgMGNM/eN78VZjSKJYGgeujoJg4BPQ6VE/qfIcJaPmuiiJBs0MDYIB8pKeSImXCDqYWEL6dZkSyro8HHHMAzFk1YP+pNIWVi8l3F+ajEFrEpTYKvdsZ4TiP/7CBaaI+0yVIq1mQ100AWeUiTn89iF8yq
       AgP8laLgMqZbM15Gm5UD7+g9/zsW0razyuclLogijvYRTMKt8vBa/rEfcx+qs8CuIrkXnD/KGfvoMDRgniWz8teaV1zfdDrkd6BhPVc5P3hI6gDY/xnSeijyyXL+XDE1ex6nfW5vNCwMiAWfDM+6k= olafkfreund@razer"
        ];
      };

      # SSH server configuration
      services.openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          PermitRootLogin = "no";
        };
      };

      # Your application configuration
      environment.systemPackages = with pkgs; [
        vim
        curl
        wget
        git
      ];

      # Networking configuration (will work in both environments)
      networking = {
        firewall = {
          enable = true;
          allowedTCPPorts = [22 80 443];
        };
      };

      # Add any additional services you need
      services.nginx = {
        enable = true;
        virtualHosts."localhost" = {
          root = pkgs.runCommand "testdir" {} ''
            mkdir -p $out
            echo "Hello from NixOS on local, AWS, and Azure!" > $out/index.html
          '';
        };
      };
    };

    # Azure-specific configuration
    azureConfig = {pkgs, ...}: {
      # Azure requires cloud-init for basic setup
      services.cloud-init = {
        enable = true;
        network.enable = true;
        settings = {
          cloud_init_modules = [
            "migrator"
            "seed_random"
            "bootcmd"
            "write-files"
            "growpart"
            "resizefs"
            "update_etc_hosts"
            "ca-certs"
            "users-groups"
            "ssh"
          ];
          system_info.distro = "nixos";
          system_info.default_user.name = "admin";
        };
      };

      # Azure network settings
      networking = {
        useDHCP = true;
        useNetworkd = true;
        # Support DHCP on first network interface
        usePredictableInterfaceNames = false;
        interfaces.eth0.useDHCP = true;
      };

      # Azure agents and utilities
      environment.systemPackages = with pkgs; [
        azure-cli
      ];
    };
  in {
    # NixOS configuration for aws-ec2 instance
    nixosConfigurations.aws-server = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        commonConfig
        # AWS-specific overrides
        {
          networking.hostName = "aws-nixos";
        }
      ];
    };

    # NixOS configuration for Azure VM instance
    nixosConfigurations.azure-server = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        commonConfig
        azureConfig
        # Azure-specific overrides
        {
          networking.hostName = "azure-nixos";
        }
      ];
    };

    # NixOS configuration for local MicroVM
    nixosConfigurations.local-vm = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        microvm.nixosModules.microvm
        commonConfig
        # Local MicroVM specific configuration
        {
          networking.hostName = "local-nixos";

          # MicroVM configuration
          microvm = {
            enable = true;
            hypervisor = "qemu";
            mem = 2048;
            vcpu = 2;
            volumes = [
              {
                mountPoint = "/";
                image = "rootfs.img";
                size = 10240; # 10GB
              }
            ];
            shares = [
              {
                tag = "ro-store";
                source = "/nix/store";
                mountPoint = "/nix/.ro-store";
              }
            ];
            interfaces = [
              {
                type = "tap";
                id = "vm-tap";
                mac = "02:00:00:00:00:01";
              }
            ];
          };

          # Network configuration for the local VM
          systemd.network = {
            enable = true;
            networks."20-lan" = {
              matchConfig.Name = "eth0";
              networkConfig = {
                DHCP = "yes";
              };
            };
          };
        }
      ];
    };

    # Generate AMI for AWS
    packages.${system} = {
      aws-ami = nixos-generators.nixosGenerate {
        inherit system;
        modules = [
          self.nixosConfigurations.aws-server.config
        ];
        format = "amazon";
      };

      # Generate VHD for Azure
      azure-vhd = nixos-generators.nixosGenerate {
        inherit system;
        modules = [
          self.nixosConfigurations.azure-server.config
          {
            # Make sure the disk has enough space for Azure
            fileSystems."/" = {
              device = "/dev/disk/by-label/nixos";
              fsType = "ext4";
              autoResize = true;
            };
            boot.growPartition = true;
            boot.kernelParams = ["console=ttyS0" "console=tty1" "nvme.shutdown_timeout=10"];
          }
        ];
        format = "azure";
      };
    };

    # Development shell with all necessary tools
    devShells.${system}.default = pkgs.mkShell {
      buildInputs = with pkgs; [
        # Infrastructure as Code
        terraform
        pulumi

        # AWS tools
        awscli2
        ssm-session-manager-plugin

        # Azure tools
        azure-cli
        azurerm-cli
        azure-storage-azcopy

        # Helpful tools
        jq
        yq
        nixos-generators
      ];

      shellHook = ''
        echo "NixOS + Terraform AWS/Azure Development Environment"
        echo "Commands:"
        echo "  - terraform: Manage cloud infrastructure"
        echo "  - aws: AWS CLI"
        echo "  - az: Azure CLI"
        echo "  - build-ami: Build the AWS AMI"
        echo "  - build-azure-vhd: Build the Azure VHD"
        echo "  - run-local: Run the local MicroVM"

        # Create helper functions
        build-ami() {
          nix build .#aws-ami
        }

        build-azure-vhd() {
          nix build .#azure-vhd
        }

        run-local() {
          sudo systemd-run --unit=nixos-microvm \
            $(nix build .#nixosConfigurations.local-vm.config.microvm.declaredRunner --print-out-paths --no-link)
          echo "MicroVM started. You can connect with:"
          echo "  ssh admin@$(ip -4 addr show vm-tap | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
        }

        # Helper for uploading VHD to Azure Storage
        upload-azure-vhd() {
          if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
            echo "Usage: upload-azure-vhd <storage-account> <container> <resource-group>"
            return 1
          fi

          local storage_account="$1"
          local container="$2"
          local resource_group="$3"
          local vhd_path="$(readlink -f ./result/disk.vhd)"

          echo "Uploading VHD to Azure Storage..."
          az storage blob upload \
            --account-name "$storage_account" \
            --container-name "$container" \
            --file "$vhd_path" \
            --name "nixos-azure.vhd" \
            --auth-mode login

          echo "VHD uploaded. You can create a VM from this image using:"
          echo "az image create --resource-group $resource_group --name nixos-image --os-type Linux --source https://$storage_account.blob.core.windows.net/$container/nixos-azure.vhd"
        }
      '';
    };
  };
}
