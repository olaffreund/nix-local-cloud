{
  description = "NixOS VM for local cloud development";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
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

    # VM Configuration
    vmConfig = {
      name ? "nixos-vm",
      vmHost ? "localhost",
    }: {
      # Basic system configuration
      system.stateVersion = "24.05";

      # Set hostname
      networking = {
        hostName = name;
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
        startWhenNeeded = false; # Make sure SSH starts at boot
        settings = {
          PermitRootLogin = "no";
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
        # Network tools for diagnostics
        inetutils
        iproute2
        nettools
      ];
    };

    # Modules for VM configuration
    vmModules = [
      # Local VM-specific configuration
      ({
        config,
        pkgs,
        ...
      }: {
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
      (vmConfig {})
    ];
  in {
    # Define packages that can be built
    packages.${system} = rec {
      # Default package is the local VM runner
      default = vm-runner;

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
          ${vm-derivation}/bin/run-*-vm -m 2048
        '';
        
      # VM image for local testing
      vm-image = let
        vm-config = self.nixosConfigurations.vm;
      in
        vm-config.config.system.build.vm;
    };

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
        ];
    };
  };
}
