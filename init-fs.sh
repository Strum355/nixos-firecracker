#!/usr/bin/env bash
set -ex
MOUNTPOINT=/mnt/firecracker-rootfs
IMAGE=result/nixos.img

mkdir -p $MOUNTPOINT
sudo umount $IMAGE || true
sudo mount $IMAGE $MOUNTPOINT
sudo chown -R "$USER":"$USER" $MOUNTPOINT
nixos-install \
  --impure --no-bootloader --no-root-passwd \
  --root $MOUNTPOINT --flake .#firecracker
mkdir -p $MOUNTPOINT/sbin
ln -sf /nix/var/nix/profiles/system/init $MOUNTPOINT/sbin/init
sudo umount $IMAGE