# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "module-library";
  ids = ["module-library"];
  checks = {
    self,
    inputs,
    system,
    pkgs,
    ...
  }: let
    fixtures = import ../../lib/modules/tests {inherit inputs system;};
    productionHome = self.lib.modules.mkHost {
      name = "standalone-fixture";
      role = "home";
      inherit system;
      ids = [
        "home-manager"
        "xdg"
        "shell"
        "stylix"
        "DE"
        "wayland"
        "browser"
        "host-armin"
        "networking-desktop"
        "desktop-password"
        "user"
        "preservation"
      ];
      args = {
        userName = "fixture";
        homeStateVersion = "26.11";
        shell = {
          enable = true;
          name = "nushell";
        };
        theme = {
          enable = true;
          base16Scheme = "gruvbox-dark";
        };
        desktop = {
          enable = true;
          name = "gnome";
          # Impression depends on x86-only syslinux in the pinned Nixpkgs.
          programs.isoWriter =
            if system == "x86_64-linux"
            then "gnome"
            else null;
        };
      };
    };
  in {
    evaluation = assert builtins.all (value: value) (builtins.attrValues fixtures.results);
      pkgs.runCommand "modules-v3-evaluation" {} "touch $out";
    exports = fixtures.build;
    standalone =
      builtins.seq productionHome.activationPackage.drvPath
      (pkgs.runCommand "production-home-sections" {} "touch $out");
  };
}
