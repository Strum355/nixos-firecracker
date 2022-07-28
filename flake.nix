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
