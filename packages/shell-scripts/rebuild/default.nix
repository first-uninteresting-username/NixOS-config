# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
_: {
  perSystem = {pkgs, ...}: {
    packages.rebuild = pkgs.writeShellApplication {
      name = "rebuild";
      runtimeInputs = with pkgs; [
        nh
      ];
      text = ''
        nh os boot github:first-uninteresting-username/NixOS-config/main#"$HOSTNAME"
      '';
    };
  };
}
