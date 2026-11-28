# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "sudo";
  ids = ["sudo"];
  module = _: {
    nixos = {
      config,
      lib,
      pkgs,
      ...
    }: let
      # The polkit prompt for run0 names the transient unit, so name the unit after the command.
      run0Named = pkgs.writeShellApplication {
        name = "run0";
        runtimeInputs = [pkgs.coreutils];
        text = ''
          real=${config.systemd.package}/bin/run0
          for arg in "$@"; do
            case "$arg" in
              -u | --unit | --unit=*) exec "$real" "$@" ;;
              --) break ;;
            esac
          done

          words=()
          for arg in "$@"; do
            case "$arg" in
              /nix/store/*) words+=("$(basename -- "$arg")") ;;
              *) words+=("$arg") ;;
            esac
          done
          slug="''${words[*]:-shell}"
          slug="''${slug// /-}"
          slug="$(printf '%s' "$slug" | tr -c 'A-Za-z0-9_.:-' '_' | cut -c1-100)"
          suffix="$(od -An -N3 -tx1 /dev/urandom | tr -d ' \n')"
          exec "$real" --unit="run0-$slug-$suffix" "$@"
        '';
      };
    in {
      environment.systemPackages = [(lib.hiPrio run0Named)];
      security = {
        sudo.enable = false;
        sudo-rs.enable = true;
        # Making you not need to write password over and over
        polkit.extraConfig = ''
          polkit.addRule(function(action, subject) {
            if (subject.isInGroup("wheel")) {
              var isNixAction = action.id.indexOf("org.nixos.") == 0;
              var isSystemdAction =
                action.id.indexOf("org.freedesktop.systemd1.") == 0;
              if (isNixAction || isSystemdAction) {
                return polkit.Result.AUTH_ADMIN_KEEP;
              }
            }
          });
        '';
      };
    };
  };
}
