# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "programs-desktop";
  ids = ["programs-desktop"];
  module = _: {
    nixos = {
      lib,
      pkgs,
      userName,
      preservationEnable,
      ...
    }: {
      preservation.preserveAt = lib.mkIf preservationEnable {
        "/persist" = {
          directories = [
            "/var/lib/kdeconnect"
          ];
          files = [
            # System-level files to persist
          ];
          users.${userName} = {
            directories = [
              ".config/kdeconnect"
            ];
            files = [
              # User-level files to persist (relative to $HOME)
            ];
          };
        };
      };

      programs = {
        kdeconnect.enable = true;
      };

      # Probably not the right place for that
      services.ananicy = {
        # Temporary
        enable = false;
        package = pkgs.ananicy-cpp;
        rulesProvider = pkgs.ananicy-rules-cachyos;
      };
    };
    home = {
      packages,
      pkgs,
      ...
    }: {
      home.packages = [
        pkgs.inkscape
        packages.flow-desktop
      ];
    };
  };
  packages = {pkgs, ...}: let
    release = builtins.fromJSON (builtins.readFile ./_flow-desktop/release.json);
    source = release.sources.${pkgs.stdenv.hostPlatform.system};
  in {
    flow-desktop = pkgs.stdenvNoCC.mkDerivation {
      pname = "flow-desktop";
      inherit (release) version;

      src = pkgs.fetchurl {
        inherit (source) url hash;
      };

      nativeBuildInputs = [
        pkgs.autoPatchelfHook
        pkgs.dpkg
        pkgs.wrapGAppsHook3
      ];

      buildInputs = [
        pkgs.stdenv.cc.cc.lib
        pkgs.gtk3
        pkgs.webkitgtk_4_1
        pkgs.glib-networking
        pkgs.gsettings-desktop-schemas
        pkgs.gst_all_1.gstreamer
        pkgs.gst_all_1.gst-plugins-base
        pkgs.gst_all_1.gst-plugins-good
        pkgs.gst_all_1.gst-plugins-bad
        pkgs.gst_all_1.gst-plugins-ugly
        pkgs.gst_all_1.gst-libav
      ];

      unpackPhase = ''
        runHook preUnpack
        dpkg-deb --extract "$src" .
        runHook postUnpack
      '';

      dontConfigure = true;
      dontBuild = true;

      installPhase = ''
        runHook preInstall
        mkdir -p "$out"
        cp -r usr/* "$out/"
        substituteInPlace "$out"/share/applications/*.desktop \
          --replace-fail 'Exec=flow' "Exec=$out/bin/flow"
        runHook postInstall
      '';

      preFixup = ''
        # Upstream's fallback searches beside the executable, but Debian stores it in lib.
        integrityScript=$(find "$out/lib" -name integrity.cjs -print -quit)
        test -n "$integrityScript"
        gappsWrapperArgs+=(
          --prefix PATH : ${pkgs.lib.makeBinPath [pkgs.nodejs]}
          --set-default FLOW_INTEGRITY_SCRIPT "$integrityScript"
        )
      '';

      passthru.updateScript = pkgs.lib.getExe (pkgs.writeShellApplication {
        name = "update-flow-desktop";
        runtimeInputs = [pkgs.python3 pkgs.nix];
        # Run the checkout script so release.json remains writable.
        text = ''
          exec python3 modules/programs-desktop/_flow-desktop/update.py
        '';
      });

      meta = {
        description = "YouTube and YouTube Music client with local recommendations";
        homepage = "https://github.com/Flow-Tube/Flow-Desktop";
        license = pkgs.lib.licenses.gpl3Only;
        mainProgram = "flow";
        platforms = ["x86_64-linux" "aarch64-linux"];
        sourceProvenance = [pkgs.lib.sourceTypes.binaryNativeCode];
      };
    };
  };
}
