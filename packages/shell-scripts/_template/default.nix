# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
_: {
  perSystem = {pkgs, ...}: let
    packagename = "CHANGEME";
  in {
    "packages.shell-scripts-${packagename}" = pkgs.writeShellApplication {
      name = packagename;
      runtimeInputs = with pkgs; [
      ];
      text = ''
        # here is the place for the script
      '';
    };
  };
}
