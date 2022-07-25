{ isContainer }:
{ pkgs, config, lib, modulesPath, ... }:
# let
#   readConfig = configfile: import (localPkgs.runCommand "config.nix" { } ''
#     echo "{" > "$out"
#     while IFS='=' read key val; do
#       [ "x''${key#CONFIG_}" != "x$key" ] || continue
#       no_firstquote="''${val#\"}";
#       echo '  "'"$key"'" = "'"''${no_firstquote%\"}"'";' >> "$out"
#     done < "${configfile}"
#     echo "}" >> $out
#   '').outPath;
# in
{
  imports = [
    "${modulesPath}/profiles/minimal.nix"
  ];

  programs.bash.promptInit = ''
    if [ "$TERM" != "dumb" -o -n "$INSIDE_EMACS" ]; then
      PS1=$'\[\e[1m\]\h\[\e[0m\]:\w\[\e[1m\]`eval "$PS1GIT"`\[\e[0m\]\$ '
      PS1GIT='[[ `git status --short 2>/dev/null` ]] && echo \*'
      [[ $TERM = xterm* ]] && PS1='\[\033]2;\h:\w\007\]'"$PS1"
    fi
  '';

  systemd = {
    services = {
      nix-daemon.enable = false;
      mount-pstore.enable = false;
      sysctl.enable = false;
    };
    sockets.nix-daemon.enable = false;
  };

  services = {
    openssh = {
      enable = true;
    };
    timesyncd.enable = false;
    udisks2.enable = false;
    getty.autologinUser = "root";
  };

  users.users.root = {
    password = "root";
  };

  system.activationScripts = {
    installInitScript = ''
      mkdir -p /sbin
      ln -fs $systemConfig/init /sbin/init
    '';
  };

  environment.systemPackages = with pkgs; [
    nano
    bash
    vim
    wget
    curl
  ];

  networking = {
    hostName = "nixos";
    dhcpcd.enable = false;
    firewall.enable = false;
    wireless.enable = false;
  };

  virtualisation.docker.enable = true;

  security = {
    polkit.enable = false;
  };

  boot = {
    kernelParams = [ "console=ttyS0" "noapic" "reboot=k" "panic=1" "pci=off" "nomodules" "rw" "init=/nix/var/nix/profiles/system/init" ];
    isContainer = isContainer;
    loader.grub.enable = false;
    kernelModules = [ "dm-mod" ];
    kernelPackages =
      let
        base = pkgs.linuxPackages_5_18;
        version = "5.18.12";
      in
      pkgs.linuxPackagesFor (pkgs.linuxKernel.manualConfig {
        inherit (pkgs) stdenv;
        inherit (pkgs) lib;
        inherit version;
        src = pkgs.fetchurl {
          url = "https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-${version}.tar.xz";
          sha256 = "0bqmp0p36551war0k7agnkfb7vq7pl3hkyprk26iyn716cdgaly5";
        };
        configfile = ./microvm-kernel-x86_64.config;
        allowImportFromDerivation = true;
      });

    # kernel = super.kernel.override {
    #   structuredExtraConfig = with lib.kernel; {
    #     PVH = yes;
    #     PARAVIRT = yes;
    #     PARAVIRT_TIME_ACCOUNTING = yes;
    #     HAVE_VIRT_CPU_ACCOUNTING_GEN = yes;
    #     VIRT_DRIVERS = yes;
    #     VIRTIO_BLK = yes;
    #     BLK_MQ_VIRTIO = yes;
    #     VIRTIO_NET = yes;
    #     VIRTIO_BALLOON = yes;
    #     VIRTIO_CONSOLE = yes;
    #     VIRTIO_MMIO = yes;
    #     VIRTIO_MMIO_CMDLINE_DEVICES = yes;
    #     VIRTIO_PCI = yes;
    #     VIRTIO_PCI_LIB = yes;
    #     VIRTIO_VSOCKETS = module;
    #     EXT4_FS = yes;
    #     MD = yes;

    #     # for Firecracker SendCtrlAltDel;
    #     SERIO_I8042 = yes;
    #     KEYBOARD_ATKBD = yes;
    #     # for Cloud-Hypervisor shutdown;
    #     ACPI_BUTTON = yes;
    #     EXPERT = yes;
    #     ACPI_REDUCED_HARDWARE_ONLY = yes;
    #   };
    # };
  };

  fileSystems."/" = {
    device = "/dev/vda";
    # options = [ "ro" ];
  };

  boot.postBootCommands =
    ''
      # After booting, register the contents of the Nix store in the Nix
      # database.
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

  system.stateVersion = "22.05";
}
