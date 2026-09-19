# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
_: {
  flake = {
    nixosModules.languages = {pkgs, ...}: {
      environment.systemPackages = with pkgs; [
        (python3.withPackages (ps: with ps; [requests]))
      ];
    };
  };
}
