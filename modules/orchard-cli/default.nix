# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "orchard-cli";
  ids = ["orchard-cli"];
  module = _: {
    nixos = {
      lib,
      userName,
      preservationEnable,
      ...
    }: {
      preservation.preserveAt = lib.mkIf preservationEnable {
        "/persist".users.${userName}.directories = [".orchard"];
      };
    };
    home = {packages, ...}: {
      home.packages = [packages.default];
    };
  };
  packages = {pkgs, ...}: let
    version = "0.30.0";
    sourceInfo = {
      x86_64-linux = {
        arch = "amd64";
        hash = "sha256-8tLXxgfcMQVzrrCf1+g+bydVRbsiBgnT+RxIhR1tQp8=";
      };
      aarch64-linux = {
        arch = "arm64";
        hash = "sha256-vThtB4w06AeIrXNXXxtjyPHEUXLsGTWZpiIAcUWYaj4=";
      };
    };
    sources = pkgs.lib.mapAttrs (_: source:
      pkgs.fetchurl {
        url = "https://github.com/LeafdTK/orchard-releases/releases/download/v${version}/orchard_${version}_linux_${source.arch}.tar.gz";
        inherit (source) hash;
      })
    sourceInfo;
  in {
    default = pkgs.stdenvNoCC.mkDerivation {
      pname = "orchard-cli";
      inherit version;
      src = sources.${pkgs.stdenv.hostPlatform.system};
      sourceRoot = ".";
      dontConfigure = true;
      dontBuild = true;
      installPhase = ''
        runHook preInstall
        install -Dm755 orchard "$out/bin/orchard"
        install -Dm644 LICENSE "$out/share/licenses/orchard-cli/LICENSE"
        install -Dm644 THIRD_PARTY_NOTICES.txt \
          "$out/share/licenses/orchard-cli/THIRD_PARTY_NOTICES.txt"
        runHook postInstall
      '';
      passthru = {
        inherit sources;
        updateScript = pkgs.nix-update-script {
          attrPath = "orchard-cli";
          extraArgs = [
            "--flake"
            "--use-github-releases"
            "--override-filename"
            "modules/orchard-cli/default.nix"
            "--subpackage"
            "sources.x86_64-linux"
            "--subpackage"
            "sources.aarch64-linux"
          ];
        };
      };
      meta = {
        description = "Orchard platform CLI";
        homepage = "https://github.com/LeafdTK/orchard-releases";
        license = pkgs.lib.licenses.agpl3Only;
        sourceProvenance = [pkgs.lib.sourceTypes.binaryNativeCode];
        mainProgram = "orchard";
        platforms = builtins.attrNames sources;
      };
    };
  };
  checks = {
    pkgs,
    packages,
    ...
  }: {
    default = pkgs.runCommand "orchard-cli-smoke" {} ''
      export HOME="$TMPDIR"
      ${packages.default}/bin/orchard --version > version.txt
      grep -F '${packages.default.version}' version.txt
      ${packages.default}/bin/orchard --help > help.txt
      test -s help.txt
      touch "$out"
    '';
  };
  docs = ''
    Installs the Orchard platform CLI as `orchard` from the pinned upstream release.
    The `orchard-cli` host ID enables it; victim and armin select it by default.
    Linux binaries for x86_64 and aarch64 use upstream SHA-256 checksums.
    Run `orchard --help` for commands.
    `passthru.updateScript` uses Nixpkgs’ `nix-update-script` for both Linux architectures.
    The scheduled package updater runs it on Mondays and Thursdays and opens an update PR.
    Run it manually from the repository root with:

    ```sh
    nix run --inputs-from . nixpkgs#nix-update -- --flake --use-update-script orchard-cli
    ```

    Configuration and credentials in `~/.orchard` persist when preservation is enabled.
    Homebrew and Go are not required.
  '';
  imperativeSteps = ''
    Run `orchard auth login` to authenticate with Orchard after installing the configuration.
  '';
}
