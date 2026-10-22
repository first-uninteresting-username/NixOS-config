# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{pkgs, ...}: let
  version = "1.41.0";
  src = pkgs.fetchurl {
    url = "https://github.com/akitaonrails/ai-usagebar/archive/refs/tags/v${version}.tar.gz";
    sha256 = "2371a9f67c8291d8313f03ed1bfbe5571f232e2ebf780202e6b0ef27815cabad";
  };
  extensionUuid = "ai-usagebar@akitaonrails.github.io";
  updateScript = pkgs.writeShellScript "update-ai-usagebar" ''
    exec ${pkgs.python3}/bin/python ${./_sources/update.py}
  '';
in {
  default = pkgs.rustPlatform.buildRustPackage {
    pname = "ai-usagebar";
    inherit version src;
    cargoLock.lockFile = ./_sources/Cargo.lock;
    passthru = {inherit updateScript;};
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
    nativeBuildInputs = [pkgs.glib];
    dontConfigure = true;
    buildPhase = ''
      runHook preBuild
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
          "['${pkgs.ptyxis}/bin/ptyxis', '--new-window', '--', tui],"
      runHook postInstall
    '';
    passthru = {
      inherit extensionUuid updateScript;
      supportedShellVersions = ["45" "46" "47" "48" "49" "50"];
    };
    meta = {
      description = "AI usage indicator for GNOME Shell";
      homepage = "https://github.com/akitaonrails/ai-usagebar";
      license = pkgs.lib.licenses.mit;
      platforms = ["x86_64-linux" "aarch64-linux"];
    };
  };
}
