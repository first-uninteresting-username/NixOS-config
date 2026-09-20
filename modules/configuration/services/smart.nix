# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
_: {
  flake = {
    nixosModules.smart = {
      lib,
      config,
      pkgs,
      ...
    }: {
      preservation.preserveAt = lib.mkIf config.custom.preservation.enable {
        "/persist" = {
          directories = [
            "/var/lib/smartmontools"
          ];
        };
      };

      environment.systemPackages = with pkgs; [smartmontools];

      services.smartd = {
        enable = true;
        notifications = {
          systembus-notify.enable = true;
          wall.enable = true;
        };
        defaults.autodetected = "-a -s (S/../.././02)";
      };
    };
  };
}
