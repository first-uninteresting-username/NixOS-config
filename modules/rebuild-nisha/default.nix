# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "rebuild-nisha";
  ids = ["rebuild-nisha"];
  module = _: {
    nixos = {packages, ...}: {
      environment.systemPackages = [
        packages.rebuild-nisha
      ];
    };
  };
  packages = {pkgs, ...}: {
    # Deploys main through the flake's deploy-rs app, so the node settings live only in deploy/.
    rebuild-nisha = pkgs.writeShellApplication {
      name = "rebuild-nisha";
      text = ''
        nix run --refresh github:first-uninteresting-username/NixOS-config/main#rebuild-nisha -- "$@"
      '';
    };
  };
}
