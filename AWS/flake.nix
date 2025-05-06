{
  description = "NixOS AWS AMI Builder";

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
  in {
    # Define packages that can be built
    packages.${system} = rec {
      # Default package is the AWS image
      default = aws-image;

      # Build AWS image as a separate derivation
      aws-image = let
        # Create a dedicated configuration for AWS
        evalConfig = import "${nixpkgs}/nixos/lib/eval-config.nix" {
          inherit system;
          modules = [
            # Import the Amazon image module explicitly
            "${nixpkgs}/nixos/modules/virtualisation/amazon-image.nix"

            # Add our host modules
            ({...}: {
              imports = getHostModules ../hosts;

              # Configure nixpkgs properly
              nixpkgs.pkgs = pkgs;
            })

            # AWS configuration
            ./configuration.nix
          ];
        };
      in
        evalConfig.config.system.build.amazonImage;

      # Upload script wrapper that calls the external script
      upload-script = pkgs.writeShellScriptBin "upload-to-aws" ''
        #!/bin/bash
        SCRIPT_DIR="$(cd "$(dirname "''${BASH_SOURCE[0]}")" && pwd)"
        exec $SCRIPT_DIR/upload-to-aws.sh "$@" "${aws-image}/nixos.img"
      '';
    };

    # Define applications (runnable commands)
    apps.${system} = {
      # Default app is to build and upload the AWS image
      default = self.apps.${system}.upload;

      # Build the AWS image
      build = {
        type = "app";
        program = toString (pkgs.writeShellScript "build-aws-image" ''
          echo "Building AWS image..."
          nix build .#aws-image
          echo "AWS image built successfully at ./result"
        '');
      };

      # Upload an AWS image
      upload = {
        type = "app";
        program = "${self.packages.${system}.upload-script}/bin/upload-to-aws";
      };
    };
  };
}
