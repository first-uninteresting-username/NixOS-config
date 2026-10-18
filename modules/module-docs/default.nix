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
  checks = {
    self,
    pkgs,
    packages,
    ...
  }: {
    # A successful docs build can still be stale; compare the checked-in reference exactly.
    default = {
      extraFiles = ["docs/module-reference.md"];
      derivation = pkgs.runCommand "check-module-docs" {} ''
        diff -u ${self}/docs/module-reference.md ${packages.reference}
        touch "$out"
      '';
    };
  };
}
