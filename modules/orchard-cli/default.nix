# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "orchard-cli";
  ids = ["orchard-cli"];
  state = {
    home.directories = [
      ".orchard"
    ];
  };
  module = {
    orchardApiUrl ? "https://orchard.iameasytoremember.com",
    orchardMcpUrl ? "https://mcp.iameasytoremember.com/",
    orchardApiTokenPath ? "/run/secrets/ORCHARD_API_TOKEN",
  }: {
    nixos = {
      lib,
      secretsEnable,
      userName,
      ...
    }: {
      config = lib.optionalAttrs secretsEnable {
        sops.secrets."ORCHARD_API_TOKEN" = {
          path = orchardApiTokenPath;
          owner = userName;
        };
      };
    };
    home = {
      lib,
      pkgs,
      packages,
      secretsEnable,
      ...
    }: let
      tokenFile = lib.escapeShellArg orchardApiTokenPath;

      # An ORCHARD_API_TOKEN already in the environment wins over the sops file.
      readToken = ''
        if [ -z "''${ORCHARD_API_TOKEN-}" ] && [ -r ${tokenFile} ]; then
          ORCHARD_API_TOKEN=$(cat ${tokenFile})
          export ORCHARD_API_TOKEN
        fi
      '';

      orchard = pkgs.symlinkJoin {
        inherit (packages.default) name;
        paths = [packages.default];
        nativeBuildInputs = [pkgs.makeWrapper];
        postBuild = ''
          wrapProgram $out/bin/orchard \
            --set-default ORCHARD_API_URL ${lib.escapeShellArg orchardApiUrl} \
            ${lib.optionalString secretsEnable "--run ${lib.escapeShellArg readToken}"}
        '';
        meta = packages.default.meta or {};
      };

      # Prints the Authorization header at connect time so the token stays out of the store.
      mcpHeaders = pkgs.writeShellScript "orchard-mcp-headers" ''
        printf '{"Authorization":"Bearer %s"}' "$(cat ${tokenFile})"
      '';
    in {
      home.packages = [orchard];

      # Without secrets, Claude Code signs in to the MCP server through OAuth.
      programs.claude-code.mcpServers.orchard =
        {
          type = "http";
          url = orchardMcpUrl;
        }
        // lib.optionalAttrs secretsEnable {
          headersHelper = "${mcpHeaders}";
        };
    };
  };
  packages = {pkgs, ...}: let
    version = "0.31.1";
    sourceInfo = {
      x86_64-linux = {
        arch = "amd64";
        hash = "sha256-YX5EbU/R4+fZxxvbMLDBxbfZMf+XOXUnUVqiP4wjKVg=";
      };
      aarch64-linux = {
        arch = "arm64";
        hash = "sha256-AEZSQKB2+F/6vZP/gnR8zeOimuNj/YDxsgYKfcBSPSk=";
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
          extraArgs = [
            "--flake"
            "--use-github-releases"
            # Subpackage hashes belong to fetchurl, whose position is in Nixpkgs.
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
    lib,
    packages,
    ...
  }: {
    default = pkgs.runCommand "orchard-cli-smoke" {} ''
      export HOME="$TMPDIR"
      ${lib.getExe packages.default} --version > version.txt
      grep -F '${packages.default.version}' version.txt
      ${lib.getExe packages.default} --help > help.txt
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
    Run it manually from the repository with:

    ```sh
    nix run .#update-packages -- orchard-cli
    ```

    Configuration and credentials in `~/.orchard` persist when preservation is enabled.
    Homebrew and Go are not required.

    The wrapper points the CLI at `orchardApiUrl` through `ORCHARD_API_URL`. It also adds the
    Orchard MCP server at `orchardMcpUrl` to Claude Code. With secrets enabled, sops-nix
    decrypts `ORCHARD_API_TOKEN` to `orchardApiTokenPath`. The CLI then reads the token from
    that file, and Claude Code sends it as a bearer token through a `headersHelper`. The token
    stays out of the Nix store. Without secrets, Claude Code signs in through OAuth instead.
  '';
  imperativeSteps = ''
    With secrets enabled, create an API token once and store it in sops. Orchard tokens expire
    after at most 90 days, so repeat these steps to rotate the token:

    ```bash
    orchard auth login
    orchard auth token create --name nixos-config --scope exec
    sops-easy secrets/secrets.yaml
    ```

    Add the printed `orch_…` value as `ORCHARD_API_TOKEN`, then rebuild. After the rebuild,
    `orchard auth logout` removes the browser login, and the CLI uses the sops token.

    Without secrets, run `orchard auth login`. Claude Code opens a browser to approve the MCP
    connection the first time it uses the Orchard tools.
  '';
}
