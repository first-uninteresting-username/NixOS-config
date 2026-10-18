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
    evaluation = lib.evalModules {
      modules = [{options = lib.mapAttrs (_: lib.mkOption) self.lib.modules.commonArgs;}];
    };
    optionsDoc = pkgs.nixosOptionsDoc {
      inherit (evaluation) options;
      transformOptions = option: option // {visible = option.visible && !(lib.hasPrefix "_module." option.name);};
    };
    reference = pkgs.runCommand "module-reference.md" {} ''
      cat > "$out" <<'HEADER'
      # Module argument reference

      > Auto-generated from the common argument declarations in `arguments/`.
      > Run `nix run .#module-docs-update` to regenerate. Do not edit manually.

      Hosts pass these settings through `args`. Selected modules request only the
      arguments needed by their applicable system and home sections.

      HEADER
      cat ${optionsDoc.optionsCommonMark} >> "$out"
    '';
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
    default = {
      extraFiles = ["docs/module-reference.md"];
      derivation = pkgs.runCommand "check-module-docs" {} ''
        diff -u ${self}/docs/module-reference.md ${packages.reference}
        touch "$out"
      '';
    };
  };
}
