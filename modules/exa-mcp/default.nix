# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "exa-mcp";
  ids = ["exa-mcp"];
  module = {
    exaMcpUrl ? "https://mcp.exa.ai/mcp",
    exaMcpTools ? [
      "web_search_exa"
      "web_fetch_exa"
      "web_search_advanced_exa"
      "agent_run"
    ],
    exaApiKeyPath ? "/run/secrets/EXA_API_KEY",
  }: {
    nixos = {
      lib,
      secretsEnable,
      userName,
      ...
    }: {
      config = lib.optionalAttrs secretsEnable {
        sops.secrets."EXA_API_KEY" = {
          path = exaApiKeyPath;
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
      # Prints the API key header at connect time so the key stays out of the store.
      mcpHeaders = pkgs.writeShellScript "exa-mcp-headers" ''
        printf '{"x-api-key":"%s"}' "$(cat ${lib.escapeShellArg exaApiKeyPath})"
      '';
    in {
      # Without secrets, the server runs keyless with Exa's free rate limits. OpenCode
      # substitutes the {file:} reference itself; Claude Code uses the headersHelper output.
      programs.mcp = {
        enable = true;
        servers.exa =
          {
            url = "${exaMcpUrl}?tools=${lib.concatStringsSep "," exaMcpTools}";
          }
          // lib.optionalAttrs secretsEnable {
            headers."x-api-key" = "{file:${exaApiKeyPath}}";
            headersHelper = "${mcpHeaders}";
          };
      };
    };
  };
  docs = ''
    Adds Exa's hosted search MCP server at `exaMcpUrl` to the shared `programs.mcp.servers`,
    so Claude Code and OpenCode can use Exa search alongside their built-in web search.
    `exaMcpTools` lists the enabled Exa tools. An explicit list replaces Exa's defaults.

    With secrets enabled, sops-nix decrypts `EXA_API_KEY` to `exaApiKeyPath`, and MCP clients
    send it in the `x-api-key` header: OpenCode through a `{file:}` reference, Claude Code
    through a `headersHelper`. The key stays out of the Nix store. Without secrets, the server
    runs keyless with Exa's free rate limits, and `agent_run` is unavailable.
  '';
  imperativeSteps = ''
    With secrets enabled, create an API key at <https://dashboard.exa.ai/api-keys> and store it
    in sops:

    ```bash
    sops-easy secrets/secrets.yaml
    ```

    Add the key as `EXA_API_KEY`, then rebuild.
  '';
}
