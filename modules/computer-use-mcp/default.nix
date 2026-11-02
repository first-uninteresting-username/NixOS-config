# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "computer-use-mcp";
  ids = ["agents" "XFCE"];
  packages = {
    lib,
    pkgs,
    ...
  }: {
    default =
      pkgs.writers.writePython3Bin "computer-use-mcp" {
        libraries = [pkgs.python3Packages.mcp pkgs.python3Packages.pillow];
        flakeIgnore = ["E501"];
      }
      (lib.replaceStrings ["@xdotool@" "@maim@"] [(lib.getExe pkgs.xdotool) (lib.getExe pkgs.maim)]
        (builtins.readFile ./_server.py));
  };
  module = _: {
    home = {
      lib,
      packages,
      ...
    }: {
      programs.mcp = {
        enable = true;
        servers.computer.command = lib.getExe packages.default;
      };
    };
  };
  docs = ''
    Hosts with both the `agents` and `XFCE` IDs get a computer-use MCP server named `computer`
    in the shared `programs.mcp.servers`, so Claude Code and OpenCode can control the X11
    desktop they run on. It takes screenshots with maim and drives the pointer and keyboard
    with xdotool. Screenshots are downscaled to 1280 pixels wide, or
    `COMPUTER_USE_MAX_WIDTH`, and all tool coordinates use screenshot pixels.
    When the agent starts without `DISPLAY`, such as over SSH, the server uses the newest X
    server socket the user owns, for example an open xrdp session.
  '';
}
