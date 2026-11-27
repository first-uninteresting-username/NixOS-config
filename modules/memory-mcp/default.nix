# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "memory-mcp";
  ids = ["agents"];
  module = {
    memoryMcpUrl ? "https://memory.iameasytoremember.com/mcp",
    memoryApiKeyPath ? "/run/secrets/MEMORY_MCP_API_KEY",
  }: {
    nixos = {
      lib,
      secretsEnable,
      userName,
      ...
    }: {
      config = lib.optionalAttrs secretsEnable {
        sops.secrets."MEMORY_MCP_API_KEY" = {
          path = memoryApiKeyPath;
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
      # Prints the bearer header at connect time so the key stays out of the store.
      mcpHeaders = pkgs.writeShellScript "memory-mcp-headers" ''
        printf '{"Authorization":"Bearer %s"}' "$(cat ${lib.escapeShellArg memoryApiKeyPath})"
      '';
    in {
      # The server rejects unauthenticated clients, so it is added only with secrets. OpenCode
      # substitutes the {file:} reference itself; Claude Code uses the headersHelper output.
      programs.mcp = lib.mkIf secretsEnable {
        enable = true;
        servers.memory = {
          url = memoryMcpUrl;
          headers.Authorization = "Bearer {file:${memoryApiKeyPath}}";
          headersHelper = "${mcpHeaders}";
        };
      };
    };
  };
  docs = ''
    The `agents` host ID enables this module. With secrets enabled, it adds the self-hosted
    [mcp-memory-service](https://github.com/doobidoo/mcp-memory-service) at `memoryMcpUrl` to
    the shared `programs.mcp.servers`, so Claude Code and OpenCode share one persistent,
    semantically searchable memory across machines.

    sops-nix decrypts `MEMORY_MCP_API_KEY` to `memoryApiKeyPath`, and MCP clients send it as a
    bearer token: OpenCode through a `{file:}` reference, Claude Code through a
    `headersHelper`. The key stays out of the Nix store. Without secrets, the server is not
    configured.
  '';
  imperativeSteps = ''
    With secrets enabled, store the server's `MCP_API_KEY` in sops:

    ```bash
    sops-easy secrets/secrets.yaml
    ```

    Add it as `MEMORY_MCP_API_KEY`, then rebuild.
  '';
}
