# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{pkgs, ...}: let
  version = "1.41.0";
  src = pkgs.fetchFromGitHub {
    owner = "akitaonrails";
    repo = "ai-usagebar";
    tag = "v${version}";
    hash = "sha256-mS5K/IntyuDEsFmsMWtKYhjsS3T3qeRAYsTqS1TsZxA=";
  };
  extensionUuid = "ai-usagebar@akitaonrails.github.io";
  shellVersion = pkgs.lib.versions.major pkgs.gnome-shell.version;
in {
  default = pkgs.rustPlatform.buildRustPackage {
    pname = "ai-usagebar";
    inherit version src;
    cargoHash = "sha256-VV7If1vQFufyFHK6C+K9LADLU90FsD7gOGcvSJ4U3wo=";
    # Updating this package also updates the extension, which shares its version and source.
    passthru.updateScript = pkgs.nix-update-script {extraArgs = ["--flake"];};
    nativeBuildInputs = [pkgs.makeWrapper] ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [pkgs.nasm];
    # Upstream's archive tests require /usr/bin/tar outside the Nix sandbox.
    checkFlags = ["--skip=claude_desktop::app::tests"];
    postInstall = ''
      rm -f "$out/bin/ai-usagebar-tray"
      install -Dm644 config.example.toml "$out/share/ai-usagebar/config.example.toml"
      install -Dm644 LICENSE "$out/share/licenses/ai-usagebar/LICENSE"
      for program in ai-usagebar ai-usagebar-tui; do
        wrapProgram "$out/bin/$program" \
          --prefix PATH : "${pkgs.lib.makeBinPath [pkgs.procps pkgs.xdg-utils pkgs.libnotify]}"
      done
    '';
    meta = {
      description = "AI provider usage and quota tracking";
      homepage = "https://github.com/akitaonrails/ai-usagebar";
      license = pkgs.lib.licenses.mit;
      mainProgram = "ai-usagebar";
      platforms = ["x86_64-linux" "aarch64-linux"];
    };
  };
  extension = pkgs.stdenvNoCC.mkDerivation {
    pname = "gnome-shell-extension-ai-usagebar";
    inherit version src;
    nativeBuildInputs = [pkgs.glib pkgs.jq];
    dontConfigure = true;
    buildPhase = ''
      runHook preBuild
      # Automatic updates can change upstream metadata; fail before installing an incompatible extension.
      jq -e --arg uuid '${extensionUuid}' '.uuid == $uuid' gnome-extension/metadata.json > /dev/null \
        || { echo "ai-usagebar changed its extension UUID; review the integration" >&2; exit 1; }
      jq -e --arg shell '${shellVersion}' '."shell-version" | index($shell)' \
        gnome-extension/metadata.json > /dev/null \
        || { echo "ai-usagebar does not support GNOME Shell ${shellVersion}" >&2; exit 1; }
      glib-compile-schemas --strict gnome-extension/schemas
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      extensionDir="$out/share/gnome-shell/extensions/${extensionUuid}"
      mkdir -p "$extensionDir"
      cp -r gnome-extension/. "$extensionDir/"
      # The configured GNOME terminal is Ptyxis.
      substituteInPlace "$extensionDir/extension.js" \
        --replace-fail "['kgx', '--', tui]," \
          "['${pkgs.lib.getExe pkgs.ptyxis}', '--new-window', '--', tui],"
      runHook postInstall
    '';
    passthru = {inherit extensionUuid;};
    meta = {
      description = "AI usage indicator for GNOME Shell";
      homepage = "https://github.com/akitaonrails/ai-usagebar";
      license = pkgs.lib.licenses.mit;
      platforms = ["x86_64-linux" "aarch64-linux"];
    };
  };
}
