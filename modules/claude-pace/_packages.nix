# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{pkgs, ...}: let
  extensionUuid = "claude-pace@first-uninteresting-username.github.io";
  shellVersion = pkgs.lib.versions.major pkgs.gnome-shell.version;
in {
  default = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "gnome-shell-extension-claude-pace";
    version = "0.1.1";
    src = pkgs.fetchFromGitHub {
      owner = "first-uninteresting-username";
      repo = "claude-pace";
      tag = "v${finalAttrs.version}";
      hash = "sha256-VGAMmYdaVwpaKw8wDERAys3EpOLo1k9v2TsXB73MXxc=";
    };
    passthru = {
      inherit extensionUuid;
      updateScript = pkgs.nix-update-script {extraArgs = ["--flake"];};
    };
    nativeBuildInputs = [pkgs.jq];
    nativeCheckInputs = [pkgs.gjs];
    dontConfigure = true;
    buildPhase = ''
      runHook preBuild
      # Automatic updates can change upstream metadata; fail before installing an incompatible extension.
      jq -e --arg uuid '${extensionUuid}' '.uuid == $uuid' metadata.json > /dev/null \
        || { echo "claude-pace changed its extension UUID; review the integration" >&2; exit 1; }
      jq -e --arg shell '${shellVersion}' '."shell-version" | index($shell)' metadata.json > /dev/null \
        || { echo "claude-pace does not support GNOME Shell ${shellVersion}" >&2; exit 1; }
      runHook postBuild
    '';
    doCheck = true;
    checkPhase = ''
      runHook preCheck
      gjs -m pace.test.js
      runHook postCheck
    '';
    installPhase = ''
      runHook preInstall
      extensionDir="$out/share/gnome-shell/extensions/${extensionUuid}"
      install -Dm644 -t "$extensionDir" metadata.json extension.js client.js pace.js stylesheet.css
      runHook postInstall
    '';
    meta = {
      description = "Claude usage and pace indicator for GNOME Shell";
      homepage = "https://github.com/first-uninteresting-username/claude-pace";
      license = pkgs.lib.licenses.gpl3Plus;
      platforms = ["x86_64-linux" "aarch64-linux"];
    };
  });
}
