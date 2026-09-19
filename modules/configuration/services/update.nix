# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{self, ...}: {
  flake = {
    nixosModules.update = {
      pkgs,
      config,
      lib,
      ...
    }: let
      flakeRef = "github:first-uninteresting-username/NixOS-config/main#${config.custom.hostname}";
    in {
      programs.nh = {
        enable = true;
        clean = {
          dates = "weekly";
          enable = true;
          extraArgs = "--keep-since 7d --keep 10";
        };
        flake = flakeRef;
      };

      environment = {
        systemPackages = [
          self.packages.${pkgs.stdenv.hostPlatform.system}.rebuild
        ];
        variables = {
          NH_OS_FLAKE = flakeRef;
        };
      };

      nix = {
        optimise = {
          automatic = true;
          dates = "weekly";
        };
      };

      systemd = {
        timers.nh-clean = lib.mkForce {
          wantedBy = ["timers.target"];
          timerConfig = {
            OnBootSec = "30min";
            RandomizedDelaySec = "30min";
            OnCalendar = "weekly";
            Persistent = false;
          };
        };

        # This will cause issues in the future
        services.nixos-upgrade = {
          description = "NixOS upgrade";
          requires = ["network-online.target"];
          after = ["network-online.target"];

          serviceConfig = {
            Type = "oneshot";
            ExecStart = pkgs.writeShellScript "upgrade" ''
              set -e
              ${pkgs.nixos-rebuild}/bin/nixos-rebuild boot \
                --flake ${lib.escapeShellArg flakeRef} \
                -L
            '';
          };
        };

        timers.nixos-upgrade = {
          description = "Run upgrade on boot and weekly";
          wantedBy = ["timers.target"];
          timerConfig = {
            OnBootSec = "30min";
            RandomizedDelaySec = "30min";
            OnCalendar = "weekly";
            Persistent = false;
          };
        };
      };
    };
  };
}
