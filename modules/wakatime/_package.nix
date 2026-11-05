# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
# nixpkgs ships 2.26.15, which ignores `exclude_ai`; 2.28.0 needs Go 1.27.3.
# Takes the package set to build from: the overlay passes `prev`, the export passes `pkgs`.
pkgs:
(pkgs.wakatime-cli.override {buildGoModule = pkgs.buildGo127Module;}).overrideAttrs
(finalAttrs: _: {
  version = "2.28.0";
  src = pkgs.fetchFromGitHub {
    owner = "wakatime";
    repo = "wakatime-cli";
    tag = "v${finalAttrs.version}";
    hash = "sha256-GWZLCL+u4tQQ0k5cQaYOPc/pZbjfrP73/SEooNusrRc=";
  };
  vendorHash = "sha256-ElSlITp0zD77nn2afNeAn/Dn17je+hyKD+mCLevBZGE=";
})
