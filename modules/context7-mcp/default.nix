# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "context7-mcp";
  ids = ["agents"];
  module = {context7McpUrl ? "https://mcp.context7.com/mcp"}: {
    home = _: {
      programs.mcp = {
        enable = true;
        servers.context7.url = context7McpUrl;
      };
    };
  };
  docs = ''
    The `agents` host ID enables this module. It adds Context7's hosted MCP server at
    `context7McpUrl` to the shared `programs.mcp.servers`, so Claude Code and OpenCode can
    look up current library documentation. The server runs keyless with Context7's free rate
    limits.
  '';
}
