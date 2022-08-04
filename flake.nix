{
  inputs = {
    nixpkgs.url = github:nixos/nixpkgs/nixos-22.05;
  };

  outputs = { self, nixpkgs, ... }:
    let
      kernelVersion = "5.10.135";
    in
    {
      nixosConfigurations.firecracker = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          (import ./configuration.nix {
            kernelVersion = kernelVersion;
          })
        ];
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
          in
          with pkgs;
          dockerTools.buildImage {
            name = "strum355/ignite-kernel";
            tag = kernelVersion;
            contents = builtins.derivation {
              name = "kernel-image";
              system = "x86_64-linux";
              builder = "${bash}/bin/bash";
              args = [
                "-c"
                ''
                  set -e
                  # ignite requires /lib/modules to be present in the image
                  ${coreutils}/bin/mkdir -p $out/boot/ $out/lib/modules
                  # copy the kernel vmlinux bin
                  ${coreutils}/bin/cp ${system.config.system.build.kernel.dev}/vmlinux $out/boot
                ''
              ];
            };
          };

        firecracker-rootfs =
          let
            system = self.nixosConfigurations.firecracker;
            pkgs = nixpkgs.legacyPackages.x86_64-linux;
          in
          import "${nixpkgs}/nixos/lib/make-disk-image.nix" {
            inherit pkgs;
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
