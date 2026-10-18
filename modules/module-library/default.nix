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
    # The alternative shell must compose without a Nushell or desktop argument.
    zshHome = self.lib.modules.mkHost {
      name = "zsh-fixture";
      role = "home";
      inherit system;
      ids = ["home-manager" "xdg" "shell" "zsh"];
      args = {
        userName = "fixture";
        homeStateVersion = "26.11";
      };
    };
    # Exercise production home sections while selected NixOS-only sections stay inactive.
    productionHome = self.lib.modules.mkHost {
      name = "standalone-fixture";
      role = "home";
      inherit system;
      ids = [
        "home-manager"
        "xdg"
        "shell"
        "nushell"
        "stylix"
        "GNOME"
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
        theme = {
          enable = true;
          base16Scheme = "gruvbox-dark";
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
        builtins.deepSeq [productionHome.activationPackage.drvPath zshHome.activationPackage.drvPath]
        (pkgs.runCommand "production-home-sections" {} "touch $out");
    };
  };
}
