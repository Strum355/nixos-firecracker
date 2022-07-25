{ isContainer }:
{ pkgs, config, lib, modulesPath, ... }:
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
    initrd.includeDefaultModules = false;
    initrd.availableKernelModules = lib.mkForce [ ];
    # initrd.availableKernelModules = [ "md_mod" "raid0" "raid1" "raid10" "raid456" "ahci" ];
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
        # inherit (base) src;
        src = pkgs.fetchurl {
          url = "https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-${version}.tar.xz";
          sha256 = "sha256-QLdNCULyVdoHSBcQ4Qg0EtBuN+Rbj52eNK6FbbN7lSc=";
        };
        configfile = ./microvm-kernel-x86_64.config;
        allowImportFromDerivation = true;
      });
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
