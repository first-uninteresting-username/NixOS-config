# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "memeity";
  ids = ["memeity"];
  state = {
    # Settings and Drive client, then the sync state, OCR models and search index, then the
    # local mirror of the synced Drive folder. Thumbnails in ~/.cache are rebuilt on demand.
    home.directories = [
      ".config/com.memeity.app"
      ".local/share/com.memeity.app"
      "memeity"
    ];
  };
  module = _: {
    home = {packages, ...}: {
      home.packages = [packages.default];
    };
  };
  packages = {pkgs, ...}: let
    version = "1.2.0";
    sourceInfo = {
      x86_64-linux = {
        arch = "amd64";
        hash = "sha256-ZYJDfwtA7VKxaGDeK3SDez5Jnnh2o8lLxIzuPhSmqmQ=";
      };
      aarch64-linux = {
        arch = "arm64";
        hash = "sha256-uT0B9g803qbG0oE4YRF9G0tM7SaBDGOjC+k3Gjmc+v0=";
      };
    };
    sources = pkgs.lib.mapAttrs (_: source:
      pkgs.fetchurl {
        url = "https://github.com/purestellenium/memeity/releases/download/v${version}/memeity_${version}_${source.arch}.deb";
        inherit (source) hash;
      })
    sourceInfo;
  in {
    # The upstream release build embeds the Google Drive OAuth client that a source build
    # lacks, so this repackages the release .deb.
    default = pkgs.stdenv.mkDerivation {
      pname = "memeity";
      inherit version;
      src = sources.${pkgs.stdenv.hostPlatform.system};
      nativeBuildInputs = [
        pkgs.autoPatchelfHook
        pkgs.dpkg
        pkgs.wrapGAppsHook3
      ];
      buildInputs = [
        pkgs.cairo
        pkgs.dbus
        pkgs.gdk-pixbuf
        pkgs.glib
        pkgs.glib-networking
        pkgs.gtk3
        pkgs.libsoup_3
        pkgs.stdenv.cc.cc.lib
        pkgs.webkitgtk_4_1
      ];
      # The tray icon loads the indicator library with dlopen.
      runtimeDependencies = [pkgs.libayatana-appindicator];
      dontConfigure = true;
      dontBuild = true;
      installPhase = ''
        runHook preInstall
        mkdir -p "$out"
        cp -r usr/bin usr/share "$out/"
        runHook postInstall
      '';
      passthru = {
        inherit sources;
        updateScript = pkgs.nix-update-script {
          extraArgs = [
            "--flake"
            "--use-github-releases"
            # Subpackage hashes belong to fetchurl, whose position is in Nixpkgs.
            "--override-filename"
            "modules/memeity/default.nix"
            "--subpackage"
            "sources.x86_64-linux"
            "--subpackage"
            "sources.aarch64-linux"
          ];
        };
      };
      meta = {
        description = "Meme folder synced through Google Drive, with OCR and tag search";
        homepage = "https://github.com/purestellenium/memeity";
        license = pkgs.lib.licenses.gpl3Only;
        sourceProvenance = [pkgs.lib.sourceTypes.binaryNativeCode];
        mainProgram = "memeity";
        platforms = builtins.attrNames sources;
      };
    };
  };
  docs = ''
    Installs memeity, a meme library that syncs a Google Drive folder to `~/memeity` and
    searches it by filename, OCR text, and tags. The package wraps the upstream release
    `.deb` for x86_64 and aarch64. Update it with `nix run .#update-packages -- memeity`;
    the in-app updater only opens the release page.

    Settings, the sync state, OCR models, the search index, and `~/memeity` persist when
    preservation is enabled. The Google sign-in stays in the Secret Service keyring.

    Bind the search pane to a key under **Settings → Keyboard → Custom Shortcuts** with the
    command `memeity`. The in-app **Launch at login** option records the current Nix store
    path, which stops working after the package updates and the old path is collected.
  '';
}
