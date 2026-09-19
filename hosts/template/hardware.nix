# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  pkgs,
  lib,
  inputs,
  config,
  ...
}: {
  zramSwap = {
    enable = true;
  };

  hardware = {
    firmware = [pkgs.linux-firmware];
    # Here you can add other hardware. options, such as microcode updates
    # sudo nix run --option experimental-features "nix-command flakes" nixpkgs#nixos-facter -- -o facter.json
    facter = lib.optionalAttrs (builtins.pathExists ./facter.json) {
      reportPath = ./facter.json;
    };
    enableAllFirmware = lib.mkForce true;
  };

  boot = {
    # Kernel modules to load at boot
    # Example: ["nvidia" "nvidia_modeset"] for proprietary GPU drivers
    kernelModules = [];
    initrd = {
      # Kernel modules to load in initrd (early boot, before root mount)
      # Example: ["btrfs" "ext4"] if root uses these filesystems
      kernelModules = [];
      # Additional kernel modules to include in initrd
      availableKernelModules = [];
    };
    # Filesystems to support
    # Example: ["btrfs" "ext4" "vfat" "ntfs"] for mounting various partition types
    supportedFilesystems = [];
    # Kernel command-line parameters
    # Example: ["quiet" "splash" "loglevel=3"] for boot behavior
    kernelParams = [];
  };

  system.stateVersion = "26.11";

  imports = [
    # https://github.com/NixOS/nixos-hardware/blob/master/flake.nix
    # Add nixos-hardware modules for your hardware here
    inputs.disko.nixosModules.disko
    ./disko.nix
  ];

  home-manager.users.${config.custom.user.name} = {osConfig, ...}: {
    home.stateVersion = osConfig.system.stateVersion;
  };
}
