# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "smart";
  ids = ["smart"];
  module = _: {
    nixos = {
      lib,
      pkgs,
      preservationEnable,
      ...
    }: {
      preservation.preserveAt = lib.mkIf preservationEnable {
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
