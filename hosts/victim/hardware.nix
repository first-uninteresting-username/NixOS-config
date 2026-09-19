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

  services = {
    scx = {
      enable = true;
      scheduler = "scx_lavd";
    };
    system76-scheduler.enable = true;
  };

  hardware = {
    firmware = [pkgs.linux-firmware];
    cpu.amd.updateMicrocode = true;
    facter = lib.optionalAttrs (builtins.pathExists ./facter.json) {
      reportPath = ./facter.json;
    };
    enableAllFirmware = lib.mkForce true;
  };

  boot = {
    supportedFilesystems = ["btrfs"];
    kernelParams = [
      "nohibernate"
      "amd_pstate=active"
      "mem_sleep_default=deep"
    ];
    kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-bore-lto;
  };

  nixpkgs.overlays = [inputs.nix-cachyos-kernel.overlays.pinned];

  system.stateVersion = "26.11";

  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-gpu-amd
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    inputs.disko.nixosModules.disko
    ./disko.nix
  ];

  home-manager.users.${config.custom.user.name} = {osConfig, ...}: {
    home.stateVersion = osConfig.system.stateVersion;
  };
}
