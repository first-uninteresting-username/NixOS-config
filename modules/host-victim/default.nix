# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "host-victim";
  ids = ["host-victim"];
  module = _: {
    nixos = {
      pkgs,
      lib,
      inputs,
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
        facter = lib.optionalAttrs (builtins.pathExists ./_sources/facter.json) {
          reportPath = ./_sources/facter.json;
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
        # Clang LTO build tuned for the Ryzen 5 7500F (Zen 4)
        kernelPackages = inputs.chaotic.legacyPackages.${pkgs.stdenv.hostPlatform.system}.linuxPackages_cachyos-lto-znver4;
      };

      system.stateVersion = "26.11";

      imports = [
        inputs.nixos-hardware.nixosModules.common-cpu-amd
        inputs.nixos-hardware.nixosModules.common-gpu-amd
        inputs.nixos-hardware.nixosModules.common-pc-ssd
        inputs.disko.nixosModules.disko
        ./_sources/disko.nix
      ];
    };
  };
}
