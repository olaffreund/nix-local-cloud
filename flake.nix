{
  description = "NixOS VM for local cloud development";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    agenix,
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
        permittedInsecurePackages = [
          # Add any insecure packages you need to permit here
        ];
      };
    };
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

    # Import VM configuration from local folder
    vmConfigFile = import ./local/configuration.nix {
      inherit lib pkgs;
      # Pass a dummy config that will be overridden when actually used
      config = {};
    };

    # Development shell with cloud provider tools
    devShells.${system} = {
      default = pkgs.mkShell {
        name = "cloud-dev-environment";
        buildInputs = with pkgs; [
          # Terraform and related tools
          terraform
          terraform-ls
          terragrunt

          # AWS tools
          awscli2
          ssm-session-manager-plugin

          # Azure tools
          azure-cli

          # GCP tools
          google-cloud-sdk

          # Supporting tools
          jq
          yq
          direnv
          nix-direnv
          pre-commit

          # Debugging and monitoring
          kubectl
          kubectx
          k9s
        ];

        shellHook = ''
          echo "🌥️  Cloud Development Environment Ready 🌥️"
          echo ""
          echo "📦 Available tools:"
          echo "   - Terraform, Terragrunt"
          echo "   - AWS CLI, Azure CLI, Google Cloud SDK"
          echo "   - Kubernetes tools: kubectl, kubectx, k9s"
          echo ""
          echo "🔄 Quick commands:"
          echo "   - AWS login:    aws sso login"
          echo "   - Azure login:  az login"
          echo "   - GCP login:    gcloud auth login"
          echo ""
          echo "🚀 To deploy infrastructure:"
          echo "   - cd AWS/terraform && terraform init && terraform apply"
          echo "   - cd Azure/terraform && terraform init && terraform apply"
          echo "   - cd GCP/terraform && terraform init && terraform apply"
        '';
      };
    };

    # Modules for VM configuration
    vmModules = [
      # Local VM-specific configuration
      ({...}: {
        imports =
          [
            "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
          ]
          ++ (getHostModules ./hosts);

        # VM-specific settings
        virtualisation = {
          # Display settings
          graphics = true;
          # Resources
          cores = 2;
          memorySize = 2048;
          diskSize = 8192;
          # This is important for EFI boot
          useBootLoader = true;
          useEFIBoot = true;
          # Port forwarding configuration
          forwardPorts = [
            {
              from = "host";
              host.port = 2222;
              guest.port = 22;
            }
          ];
        };

        # Set up boot loader for VM
        boot.loader.systemd-boot.enable = true;
        boot.loader.efi.canTouchEfiVariables = true;

        # Network setup with DHCP for VM
        networking.useDHCP = true;
      })
      # Include the common VM configuration
      (vmConfigFile {})
    ];
  in {
    # Define packages that can be built
    packages.${system} = rec {
      # Default package is the local VM runner
      default = vm-runner;

      # VM image for local testing
      vm-image = let
        vm-config = self.nixosConfigurations.vm;
      in
        vm-config.config.system.build.vm;

      # Local VM runner script
      vm-runner = let
        vm-config = self.nixosConfigurations.vm;
        vm-derivation = vm-config.config.system.build.vm;
      in
        pkgs.writeShellScriptBin "run-vm" ''
          #!${pkgs.runtimeShell}
          echo "Starting NixOS VM..."
          echo "SSH will be available on localhost:2222 once the VM is fully booted"
          echo "Connect with: ssh nixos@localhost -p 2222"
          echo "Password login is enabled, you can use: nixos/nixos"

          # Direct execution of the VM symlink
          if [ -e "${vm-derivation}/bin/run-nixos-vm-vm" ]; then
            echo "Found VM binary: ${vm-derivation}/bin/run-nixos-vm-vm"
            ${vm-derivation}/bin/run-nixos-vm-vm -m 2048
          else
            echo "Error: Could not find expected VM binary at ${vm-derivation}/bin/run-nixos-vm-vm"
            echo "Contents of directory:"
            ls -la ${vm-derivation}/bin
            exit 1
          fi
        '';
    };

    # Export devShells to the flake outputs
    inherit devShells;

    # Define applications (runnable commands)
    apps.${system} = {
      # Default app is to run the local VM
      default = self.apps.${system}.runVM;

      # Run the local VM
      runVM = {
        type = "app";
        program = "${self.packages.${system}.vm-runner}/bin/run-vm";
      };
    };

    # Define NixOS configurations
    nixosConfigurations.vm = lib.nixosSystem {
      inherit system;
      modules =
        vmModules
        ++ [
          # Properly configure nixpkgs to use our pkgs
          {nixpkgs.pkgs = pkgs;}
          # Add agenix module
          agenix.nixosModules.default
          ./secrets/secrets.nix
        ];
    };
  };
}
