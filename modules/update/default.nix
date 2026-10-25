# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "update";
  ids = ["update"];
  module = _: {
    nixos = {
      pkgs,
      lib,
      hostName,
      packages,
      ...
    }: let
      flakeRef = "github:first-uninteresting-username/NixOS-config/main#${hostName}";
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
          packages.rebuild
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
        # Root and users cache remote flakes separately; never reuse a stale revision.
        settings.tarball-ttl = 0;
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
              ${lib.getExe pkgs.nixos-rebuild} boot \
                --flake ${lib.escapeShellArg flakeRef} \
                --refresh \
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
  packages = {pkgs, ...}: {
    rebuild = pkgs.writeShellApplication {
      name = "rebuild";
      runtimeInputs = with pkgs; [
        nh
      ];
      text = ''
        nh os boot --refresh github:first-uninteresting-username/NixOS-config/main#"$HOSTNAME"
      '';
    };
  };
  checks = {
    self,
    inputs,
    lib,
    pkgs,
    system,
    ...
  }:
    lib.optionalAttrs (system == "x86_64-linux") {
      default = (import ./_checks/default.nix {inherit self inputs lib pkgs;}).check;
    };
}
