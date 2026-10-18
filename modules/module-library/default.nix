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
    standalone = {
      extraFiles = [
        "modules/home-manager/default.nix"
        "modules/xdg/default.nix"
        "modules/shell/default.nix"
        "modules/shell-programs/default.nix"
        "modules/nushell/default.nix"
        "modules/zsh/default.nix"
        "modules/stylix/default.nix"
        "modules/stylix/_style.nix"
        "modules/GNOME/default.nix"
        "modules/DE-programs-gnome/default.nix"
        "modules/wayland/default.nix"
        "modules/browser/default.nix"
        "modules/host-armin/default.nix"
        "modules/networking-desktop/default.nix"
        "modules/desktop-password/default.nix"
        "modules/user/default.nix"
        "modules/preservation/default.nix"
      ];
      derivation =
        builtins.seq productionHome.activationPackage.drvPath
        (pkgs.runCommand "production-home-sections" {} "touch $out");
    };
  };
}
