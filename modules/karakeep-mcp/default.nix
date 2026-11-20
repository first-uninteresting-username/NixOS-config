# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "karakeep-mcp";
  ids = ["agents"];
  packages = {pkgs, ...}: {
    # The npm release ships one self-contained bundle, so no node_modules are needed.
    default = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
      pname = "karakeep-mcp";
      version = "0.35.0";
      src = pkgs.fetchurl {
        url = "https://registry.npmjs.org/@karakeep/mcp/-/mcp-${finalAttrs.version}.tgz";
        hash = "sha256-HikbE7fOCGCoJC3sk1WuNu81TMQHY/BfblWNQzSIC1k=";
      };
      nativeBuildInputs = [pkgs.makeWrapper];
      installPhase = ''
        runHook preInstall
        install -Dm644 dist/index.js $out/lib/karakeep-mcp/index.js
        makeWrapper ${pkgs.lib.getExe pkgs.nodejs} $out/bin/karakeep-mcp \
          --add-flags $out/lib/karakeep-mcp/index.js
        runHook postInstall
      '';
      passthru.updateScript = pkgs.nix-update-script {extraArgs = ["--flake"];};
      meta = {
        description = "MCP server for Karakeep";
        homepage = "https://github.com/karakeep-app/karakeep/tree/main/apps/mcp";
        license = pkgs.lib.licenses.agpl3Only;
        mainProgram = "karakeep-mcp";
      };
    });
  };
  module = {
    karakeepUrl ? "https://karakeep.iameasytoremember.com",
    karakeepApiKeyPath ? "/run/secrets/KARAKEEP_API_KEY",
  }: {
    nixos = {
      lib,
      secretsEnable,
      userName,
      ...
    }: {
      config = lib.optionalAttrs secretsEnable {
        sops.secrets."KARAKEEP_API_KEY" = {
          path = karakeepApiKeyPath;
          owner = userName;
        };
      };
    };
    home = {
      lib,
      packages,
      pkgs,
      secretsEnable,
      ...
    }: let
      # Reads the key at start so it stays out of the Nix store and the MCP client config.
      server = pkgs.writeShellScript "karakeep-mcp" ''
        KARAKEEP_API_KEY="$(cat ${lib.escapeShellArg karakeepApiKeyPath})"
        export KARAKEEP_API_KEY
        export KARAKEEP_API_ADDR=${lib.escapeShellArg karakeepUrl}
        exec ${lib.getExe packages.default}
      '';
    in {
      # Every tool needs an API key, so the server is added only with secrets.
      programs.mcp = lib.mkIf secretsEnable {
        enable = true;
        servers.karakeep.command = "${server}";
      };
    };
  };
  docs = ''
    The `agents` host ID enables this module. With secrets enabled, it adds Karakeep's stdio
    MCP server to the shared `programs.mcp.servers`, so Claude Code and OpenCode can search,
    create, tag and organise bookmarks on the self-hosted Karakeep at `karakeepUrl`.

    The package installs the bundled `@karakeep/mcp` npm release. sops-nix decrypts
    `KARAKEEP_API_KEY` to `karakeepApiKeyPath`, and a wrapper reads it when the server starts,
    so the key stays out of the Nix store. Without secrets, the server is not configured.
  '';
  imperativeSteps = ''
    With secrets enabled, create an API key in Karakeep under Settings → API Keys and store it
    in sops as `KARAKEEP_API_KEY`:

    ```bash
    sops-easy secrets/secrets.yaml
    ```

    Then rebuild.
  '';
}
