{
  inputs = {
    nixpkgs.url = github:nixos/nixpkgs/nixos-22.05;
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-generators, ... }:
    let
      firecrackerSystem = { isContainer }:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            (import ./configuration.nix {
              isContainer = isContainer;
            })
          ];
        };
    in
    {
      nixosConfigurations.firecracker-container =
        firecrackerSystem { isContainer = true; };

      nixosConfigurations.firecracker =
        firecrackerSystem { isContainer = false; };

      firecracker-vmlinux =
        let system = self.nixosConfigurations.firecracker;
        in system.config.system.build.kernel.dev;

      firecracker-rootfs =
        let
          system = self.nixosConfigurations.firecracker-container;
        in
        import "${nixpkgs}/nixos/lib/make-disk-image.nix" {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          lib = nixpkgs.lib;
          diskSize = "auto";
          config = system.config;
          additionalSpace = "2G";
          format = "raw";
          partitionTableType = "none";
          installBootLoader = false;
          fsType = "ext4";
        };

    };
}
