# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  lib,
  pkgs,
  commonArgs,
}: let
  # Reuse the NixOS option renderer so types, nested options, and defaults stay consistent.
  evaluation = lib.evalModules {
    modules = [{options = lib.mapAttrs (_: lib.mkOption) commonArgs;}];
  };
  optionsDoc = pkgs.nixosOptionsDoc {
    inherit (evaluation) options;
    transformOptions = option: option // {visible = option.visible && !(lib.hasPrefix "_module." option.name);};
  };
in
  pkgs.runCommand "module-reference.md" {} ''
    cat > "$out" <<'HEADER'
    # Module argument reference

    > Auto-generated from the common argument declarations in `arguments/`.
    > Run `nix run .#module-docs-update` to regenerate. Do not edit manually.

    Hosts pass these settings through `args`. Selected modules request only the
    arguments needed by their applicable system and home sections.

    HEADER
    cat ${optionsDoc.optionsCommonMark} >> "$out"
  ''
