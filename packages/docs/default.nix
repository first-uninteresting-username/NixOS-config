# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{self, ...}: {
  perSystem = {
    pkgs,
    lib,
    self',
    ...
  }: let
    customModules = with self.nixosModules; [
      DE
      hostname
      preservation
      shell
      stylix
      user
    ];
    baseModules = import (pkgs.path + "/nixos/modules/module-list.nix");
    eval = lib.evalModules {
      modules = baseModules ++ customModules ++ [{nixpkgs.hostPlatform = pkgs.stdenv.hostPlatform.system;} {_module.check = false;}];
    };
    optionsDoc = pkgs.nixosOptionsDoc {
      inherit (eval) options;
      transformOptions = opt:
        opt
        // {
          visible = opt.visible && lib.hasPrefix "custom." opt.name;
        };
    };
    header = pkgs.writeText "header.md" ''
      # Module Reference

      > Auto-generated from `options.custom.*`. Do not edit manually.
      > Regenerate with `nix build .#module-reference` or `nix run .#update-module-docs`.

      All options are under `custom.*` and are provided by `self.nixosModules.*`.

    '';
  in {
    packages.module-reference = pkgs.runCommand "module-reference.md" {nativeBuildInputs = [pkgs.gnused];} ''
      cat ${header} > $out
      echo "" >> $out
      # Strip /nix/store hash from declared-by paths for reproducible diffs
      sed -E 's|/nix/store/[^/]+-source/||g' ${optionsDoc.optionsCommonMark} >> $out
    '';

    packages.update-module-docs = pkgs.writeShellApplication {
      name = "update-module-docs";
      runtimeInputs = [pkgs.coreutils];
      text = ''
        set -euo pipefail
        src="${self'.packages.module-reference}"
        dst="docs/module-reference.md"
        echo "Updating $dst from $src"
        cp "$src" "$dst"
        echo "Done. Please commit the changes."
      '';
    };

    checks.module-docs = pkgs.runCommand "check-module-docs" {} ''
      echo "Checking docs/module-reference.md is up to date..."
      if ! diff -u ${self}/docs/module-reference.md ${self'.packages.module-reference} > $out.log 2>&1; then
        echo "docs/module-reference.md is out of date. Run 'nix run .#update-module-docs' to regenerate."
        cat $out.log
        exit 1
      fi
      echo "OK" > $out
    '';
  };
}
