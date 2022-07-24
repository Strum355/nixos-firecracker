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

  services = {
    openssh = {
      enable = true;
    };
    timesyncd.enable = false;
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
    dhcpcd.enable = false;
    hostName = "nixos";
  };

  systemd.services.nix-daemon.enable = false;
  systemd.sockets.nix-daemon.enable = false;

  boot = {
    initrd.supportedFilesystems = [ "ext4" ];
    kernelParams = [ "console=ttyS0" "noapic" "reboot=k" "panic=1" "pci=off" "nomodules" "rw" "init=/nix/var/nix/profiles/system/init"];
    isContainer = isContainer;
    loader.grub.enable = false;
    kernelPackages = pkgs.linuxPackages_latest.extend (self: super: {
      kernel = super.kernel.override {
        extraConfig = ''
          PVH y
          PARAVIRT y
          PARAVIRT_TIME_ACCOUNTING y
          HAVE_VIRT_CPU_ACCOUNTING_GEN y
          VIRT_DRIVERS y
          VIRTIO_BLK y
          BLK_MQ_VIRTIO y
          VIRTIO_NET y
          VIRTIO_BALLOON y
          VIRTIO_CONSOLE y
          VIRTIO_MMIO y
          VIRTIO_MMIO_CMDLINE_DEVICES y
          VIRTIO_PCI y
          VIRTIO_PCI_LIB y
          VIRTIO_VSOCKETS m
          EXT4_FS y

          # for Firecracker SendCtrlAltDel
          SERIO_I8042 y
          KEYBOARD_ATKBD y
          # for Cloud-Hypervisor shutdown
          ACPI_BUTTON y
          EXPERT y
          ACPI_REDUCED_HARDWARE_ONLY y
        '';
      };
    });
  };

  fileSystems."/" = {
    device = "/dev/vda";
    fsType = "ext4";
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

  system.stateVersion = "22.05";
}
