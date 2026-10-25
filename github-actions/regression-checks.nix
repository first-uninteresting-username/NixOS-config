# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  inputs,
  lib,
}: let
  inherit (inputs) self;
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
  fixture = path: import path {inherit self inputs lib pkgs;};
in {
  x86_64-linux = {
    persistence-without-user-state =
      (fixture ../modules/preservation/_checks/persistence.nix).regression;
    upgrade = (fixture ../modules/update/_checks/default.nix).regression;
  };
}
