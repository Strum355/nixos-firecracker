{ kernelVersion }:
{ pkgs, config, lib, modulesPath, ... }:
let
  systemdMini = pkgs.systemdMinimal.override {
    withAnalyze = true;
    withApparmor = true;
    withLogind = true;
    withTimesyncd = true;
    withCoredump = true;
    withCompression = true;
    withFido2 = false;
    withTpm2Tss = false;
  };
in
with lib; with pkgs; {
  imports = [
    "${modulesPath}/profiles/minimal.nix"
  ];

  systemd = {
    package = systemdMini;
    services = {
      nix-daemon.enable = false;
      mount-pstore.enable = false;
      sysctl.enable = false;
      journald.enable = false;
      user-sessions.enable = false;
      shutdownRamfs.enable = false;
    };
    sockets.nix-daemon.enable = false;
  };

  services = {
    openssh = {
      enable = true;
      startWhenNeeded = true;
      permitRootLogin = "yes";
    };
    # timesyncd.enable = false;
    udisks2.enable = false;
    # getty.autologinUser = "root";
    nscd.config = replaceStrings
      [ "server-user             nscd" ]
      [ "server-user             root" ]
      (builtins.readFile "${modulesPath}/services/system/nscd.conf");
  };

  users.users.root = {
    password = "root";
  };

  system = {
    stateVersion = "22.05";
    activationScripts = {
      installInitScript = ''
        mkdir -p /sbin
        ln -fs $systemConfig/init /sbin/init
      '';
    };
  };

  environment = {
    defaultPackages = [
      nano
      curl
      nerdctl
      iptables
      coreutils
      time
      which
      gnused
      gnutar
      gzip
      less
      getent
      gawk
      findutils
      netcat
    ];
  };

  nixpkgs.overlays = [
    (self: super: {
      iptables = super.iptables-legacy;
      containerd = (callPackage "${path}/pkgs/applications/virtualization/containerd" {
        btrfs-progs = null;
      });
      openssh = (super.openssh.overrideAttrs (final: prev: {
        doCheck = false;
      })).override {
        withFIDO = false;
        withKerberos = false;
      };
      nerdctl = super.nerdctl.overrideAttrs (final: prev: {
        postInstall = ''
          wrapProgram $out/bin/nerdctl \
            --prefix CNI_PATH : "${cni-plugins}/bin"
          installShellCompletion --cmd nerdctl \
            --bash <($out/bin/nerdctl completion bash) \
            --fish <($out/bin/nerdctl completion fish) \
            --zsh <($out/bin/nerdctl completion zsh)
        '';
      });
      systemdStage1 = systemdMini;
      # systemdMinimal = systemdMini;
      # ffs this is causing a dup
    })
  ];

  networking = {
    hostName = "nixos";
    resolvconf.enable = false;
    dhcpcd.enable = false;
    firewall.enable = false;
    wireless.enable = false;
  };

  virtualisation = {
    docker = {
      enable = false;
      enableOnBoot = false;
    };
    podman = {
      # enable = true;
      # dockerCompat = true;
    };
    containerd = {
      enable = true;
    };
  };

  security = {
    audit.enable = false;
    polkit.enable = false;
    sudo.enable = false;
  };

  boot = {
    kernelParams = [ "console=ttyS0" "noapic" "reboot=k" "panic=1" "pci=off" "nomodules" "rw" "init=/nix/var/nix/profiles/system/init" ];
    loader.grub.enable = false;
    initrd.includeDefaultModules = false;
    initrd.availableKernelModules = mkForce [ ];
    kernelModules = [ "dm-mod" ];
    kernelPackages =
      let
        version = kernelVersion; # e.g. 5.10.135
        pkgsVersion = concatStringsSep "_" (take 2 (splitString "." version)); # e.g. 5_10
        majorVersion = head (splitString "." version); # e.g. 5
        base = "linuxPackages_${pkgsVersion}";
      in
      linuxPackagesFor (linuxKernel.manualConfig {
        inherit stdenv lib version;
        src = fetchTarball {
          url = "https://cdn.kernel.org/pub/linux/kernel/v${majorVersion}.x/linux-${version}.tar.xz";
          sha256 = "sha256-qNCcrECmuBE9YDwXSs0hbe7clhqczfJeEGP/nNjE1zY=";
        };
        configfile = ./microvm-kernel-x86_64.config;
        allowImportFromDerivation = true;
      });
  };

  fileSystems = {
    "/" = {
      device = "/dev/vda";
      # options = [ "ro" ];
      neededForBoot = true;
    };
  };

  boot.postBootCommands = ''
    # After booting, register the contents of the Nix store in the Nix database.
    if [ -f /nix-path-registration ]; then
      ${config.nix.package.out}/bin/nix-store --load-db \
        < /nix-path-registration &&
      rm /nix-path-registration
    fi
    # nixos-rebuild also requires a "system" profile
    ${config.nix.package.out}/bin/nix-env -p /nix/var/nix/profiles/system \
      --set /run/current-system
  '';

  nix.gc.automatic = true;
}
