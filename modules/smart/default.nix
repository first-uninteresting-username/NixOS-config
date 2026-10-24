# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "smart";
  ids = ["smart"];
  state = {
    nixos.directories = [
      "/var/lib/smartmontools"
    ];
  };
  module = _: {
    nixos = {pkgs, ...}: {
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
