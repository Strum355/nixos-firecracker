{
  inputs = {
    nixpkgs.url = github:nixos/nixpkgs/nixos-22.05;
  };

  outputs = { self, nixpkgs, ... }:
    {
      nixosConfigurations = {
        firecracker = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ ./configuration.nix ];
        };
      };

      packages.x86_64-linux = {
        firecracker-vmlinux =
          let
            system = self.nixosConfigurations.firecracker;
          in
          system.config.system.build.kernel.dev;

        ignite-kernel-image =
          let
            system = self.nixosConfigurations.firecracker;
            pkgs = nixpkgs.legacyPackages.x86_64-linux;
          in pkgs.dockerTools.buildImage {
            name = "strum355/ignite-kernel";
            tag = "5.18.12";
            contents = builtins.derivation {
              name = "kernel-image";
              system = "x86_64-linux";
              builder = "${pkgs.bash}/bin/bash";
              args = [
                "-c" 
                ''
                  set -e
                  ${pkgs.coreutils}/bin/mkdir -p $out/boot/ $out/lib/modules
                  ${pkgs.coreutils}/bin/cp ${system.config.system.build.kernel.dev}/vmlinux $out/boot
                ''
              ];
            };
          };

        firecracker-rootfs =
          let
            system = self.nixosConfigurations.firecracker;
          in
          import "${nixpkgs}/nixos/lib/make-disk-image.nix" {
            pkgs = nixpkgs.legacyPackages.x86_64-linux;
            inherit (nixpkgs) lib;
            diskSize = "auto";
            config = system.config;
            additionalSpace = "1K";
            format = "raw";
            partitionTableType = "none";
            installBootLoader = false;
            fsType = "ext4";
            copyChannel = false;
          };
      };
    };
}
