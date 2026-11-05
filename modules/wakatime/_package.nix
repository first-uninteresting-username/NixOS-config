# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
# nixpkgs ships 2.26.15, which ignores `exclude_ai`; 2.28.0 needs Go 1.27.3.
# Takes the package set to build from: the overlay passes `prev`, the export passes `pkgs`.
pkgs: let
  # `exclude_ai` first shipped in this release.
  minimum = "2.27.1";
in
  # Fail instead of downgrading once Nixpkgs catches up: then delete this file and the overlay.
  if pkgs.lib.versionAtLeast pkgs.wakatime-cli.version minimum
  then
    throw ''
      wakatime: Nixpkgs now ships wakatime-cli ${pkgs.wakatime-cli.version} (>= ${minimum}).
      Remove modules/wakatime/_package.nix and its overlay and package export.''
  else
    (pkgs.wakatime-cli.override {buildGoModule = pkgs.buildGo127Module;}).overrideAttrs
    (finalAttrs: previous: let
      attrs = {
        version = "2.28.0";
        src = pkgs.fetchFromGitHub {
          owner = "wakatime";
          repo = "wakatime-cli";
          tag = "v${finalAttrs.version}";
          hash = "sha256-GWZLCL+u4tQQ0k5cQaYOPc/pZbjfrP73/SEooNusrRc=";
        };
        vendorHash = "sha256-ElSlITp0zD77nn2afNeAn/Dn17je+hyKD+mCLevBZGE=";
        passthru =
          previous.passthru
          // {
            updateScript = pkgs.nix-update-script {
              extraArgs = ["--flake" "--override-filename" "modules/wakatime/_package.nix"];
            };
          };
      };
      # The update runner and nix-update locate the pins through this repository position.
    in
      attrs // {pos = builtins.unsafeGetAttrPos "version" attrs;})
