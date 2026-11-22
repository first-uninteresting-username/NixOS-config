# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "programs-desktop";
  ids = ["programs-desktop"];
  state = {
    nixos.directories = [
      "/var/lib/kdeconnect"
    ];
    home.directories = [
      ".config/kdeconnect"
      ".config/supersonic"
    ];
  };
  module = _: {
    nixos = {pkgs, ...}: {
      programs = {
        kdeconnect.enable = true;
      };

      # Probably not the right place for that
      services.ananicy = {
        # Temporary
        enable = false;
        package = pkgs.ananicy-cpp;
        rulesProvider = pkgs.ananicy-rules-cachyos;
      };
    };
    home = {pkgs, ...}: {
      home.packages = [
        pkgs.inkscape
        pkgs.supersonic
      ];
    };
  };
}
