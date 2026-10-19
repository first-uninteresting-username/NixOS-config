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
    exports = fixtures.build;
    evaluation = assert builtins.all (value: value) (builtins.attrValues fixtures.results);
    assert builtins.isString productionHome.activationPackage.drvPath;
    assert builtins.isString zshHome.activationPackage.drvPath;
      pkgs.runCommand "modules-v3-evaluation" {} "touch $out";
  };
}
