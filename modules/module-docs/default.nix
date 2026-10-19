# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "module-docs";
  ids = ["module-docs"];
  packages = {
    self,
    lib,
    pkgs,
    ...
  }: let
    reference = import ../../lib/modules/argument-reference.nix {
      inherit lib pkgs;
      commonArgs = self.lib.modules.commonArgs;
    };
  in {
    inherit reference;
    update = pkgs.writeShellApplication {
      name = "update-module-docs";
      runtimeInputs = [pkgs.coreutils];
      text = ''
        cp ${reference} docs/module-reference.md
      '';
    };
  };
}
