# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "vikunja-mcp";
  ids = ["agents"];
  module = {
    vikunjaMcpUrl ? "https://vikunja.iameasytoremember.com/api/v2/mcp",
    vikunjaApiTokenPath ? "/run/secrets/VIKUNJA_API_TOKEN",
  }: {
    nixos = {
      lib,
      secretsEnable,
      userName,
      ...
    }: {
      config = lib.optionalAttrs secretsEnable {
        sops.secrets."VIKUNJA_API_TOKEN" = {
          path = vikunjaApiTokenPath;
          owner = userName;
        };
      };
    };
    home = {
      lib,
      pkgs,
      secretsEnable,
      ...
    }: let
      # Prints the bearer header at connect time so the token stays out of the store.
      mcpHeaders = pkgs.writeShellScript "vikunja-mcp-headers" ''
        printf '{"Authorization":"Bearer %s"}' "$(cat ${lib.escapeShellArg vikunjaApiTokenPath})"
      '';
    in {
      # The server rejects unauthenticated clients, so it is added only with secrets. OpenCode
      # substitutes the {file:} reference itself; Claude Code uses the headersHelper output.
      programs.mcp = lib.mkIf secretsEnable {
        enable = true;
        servers.vikunja = {
          url = vikunjaMcpUrl;
          headers.Authorization = "Bearer {file:${vikunjaApiTokenPath}}";
          headersHelper = "${mcpHeaders}";
        };
      };
    };
  };
  docs = ''
    The `agents` host ID enables this module. With secrets enabled, it adds the self-hosted
    Vikunja MCP server at `vikunjaMcpUrl` to the shared `programs.mcp.servers`, so Claude Code
    and OpenCode can manage Vikunja projects and tasks.

    sops-nix decrypts `VIKUNJA_API_TOKEN` to `vikunjaApiTokenPath`, and MCP clients send it as
    a bearer token: OpenCode through a `{file:}` reference, Claude Code through a
    `headersHelper`. The token stays out of the Nix store. Without secrets, the server is not
    configured.
  '';
  imperativeSteps = ''
    With secrets enabled, create an API token in Vikunja under Settings → API Tokens and store
    it in sops:

    ```bash
    sops-easy secrets/secrets.yaml
    ```

    Add the token as `VIKUNJA_API_TOKEN`, then rebuild.
  '';
}
