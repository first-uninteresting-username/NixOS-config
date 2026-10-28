# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "host-armin";
  ids = ["host-armin"];
  state = {
    nixos.directories = [
      "/var/lib/fprint"
    ];
  };
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

      environment.systemPackages = with pkgs; [
        framework-tool
        framework-tool-tui
      ];

      services = {
        scx = {
          enable = true;
          scheduler = "scx_lavd";
          extraArgs = ["--autopower"];
        };
        system76-scheduler.enable = true;
        fprintd.enable = true;
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
        ];
        # This is the only kernel with 300hz timer, which should marginally improve battery life
        kernelPackages = inputs.chaotic.legacyPackages.${pkgs.stdenv.hostPlatform.system}.linuxPackages_cachyos-server;
      };

      systemd.services.set-default-power-profile = {
        description = "Set default power profile to power-saver";
        after = ["power-profiles-daemon.service"];
        requires = ["power-profiles-daemon.service"];
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          RemainAfterExit = true;
          Type = "oneshot";
          ExecStart = "${pkgs.power-profiles-daemon}/bin/powerprofilesctl set power-saver";
        };
      };

      system.stateVersion = "26.11";

      imports = [
        inputs.nixos-hardware.nixosModules.framework-13-7040-amd
        inputs.disko.nixosModules.disko
        ./_sources/disko.nix
      ];
    };
  };
}
