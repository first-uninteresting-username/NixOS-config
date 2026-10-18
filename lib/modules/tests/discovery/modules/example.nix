# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule}: [
  (mkModule {
    name = "discovered";
    packages = {pkgs}: {default = pkgs.writeText "discovered-package" "fixture";};
    checks = {
      pkgs,
      system,
      lib,
    }:
      lib.optionalAttrs (system == "x86_64-linux") {
        default = {
          derivation = pkgs.runCommand "discovered-check" {} "touch $out";
          extraFiles = ["shared/helper.nix"];
        };
      };
    module = {userName}: {
      home = _: {
        home.username = userName;
        home.homeDirectory = "/home/${userName}";
        home.stateVersion = "26.05";
      };
    };
  })
  (mkModule {
    name = "sibling";
    checks = {pkgs}: {helper = pkgs.runCommand "sibling-check" {} "touch $out";};
  })
]
