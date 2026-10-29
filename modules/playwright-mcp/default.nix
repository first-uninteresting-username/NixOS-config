# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "playwright-mcp";
  ids = ["agents"];
  module = {playwrightMcpArgs ? []}: {
    home = {
      lib,
      pkgs,
      ...
    }: {
      programs.mcp = {
        enable = true;
        servers.playwright = {
          command = lib.getExe pkgs.playwright-mcp;
          args = playwrightMcpArgs;
        };
      };
    };
  };
  docs = ''
    The `agents` host ID enables this module. It adds the Playwright MCP server from Nixpkgs to
    the shared `programs.mcp.servers`, so Claude Code and OpenCode can drive a browser.
    The Nixpkgs package bundles Playwright's Chromium and keeps the browser profile in memory.
    The browser window is visible by default. Pass server flags, such as `--headless`, through
    `playwrightMcpArgs`.
  '';
}
