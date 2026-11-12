# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{pkgs}: let
  inherit (pkgs) lib;
  godot = pkgs.godot_4_7;
in
  pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "gradient";
    version = "0-unstable-2026-11-12";
    src = pkgs.fetchFromGitHub {
      owner = "first-uninteresting-username";
      repo = "gradient";
      rev = "fb9cee90148322cd713248de4cd81deb1ace376a";
      hash = "sha256-H07QCeB2znarBq2vIeLaSOV8CL3pCN+K6vPjKKiQVB4=";
    };
    passthru.updateScript = pkgs.nix-update-script {extraArgs = ["--flake" "--version=branch"];};

    nativeBuildInputs = [godot pkgs.copyDesktopItems pkgs.makeWrapper];

    # A resource pack needs no export templates; the nixpkgs Godot runtime loads it.
    buildPhase = ''
      runHook preBuild
      export HOME="$TMPDIR"
      godot --headless --path . --import
      godot --headless --path . --export-pack Linux gradient.pck
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      install -Dm644 gradient.pck "$out/share/gradient/gradient.pck"
      install -Dm644 icon.svg "$out/share/icons/hicolor/scalable/apps/gradient.svg"
      makeWrapper ${lib.getExe godot} "$out/bin/gradient" \
        --add-flags "--main-pack $out/share/gradient/gradient.pck"
      runHook postInstall
    '';

    desktopItems = [
      (pkgs.makeDesktopItem {
        name = "gradient";
        desktopName = "GRADIENT";
        comment = finalAttrs.meta.description;
        exec = "gradient";
        icon = "gradient";
        categories = ["Game" "ArcadeGame"];
      })
    ];

    meta = {
      description = "Endless downhill ball-runner";
      homepage = "https://github.com/first-uninteresting-username/gradient";
      license = lib.licenses.agpl3Only;
      mainProgram = "gradient";
      platforms = ["x86_64-linux" "aarch64-linux"];
    };
  })
