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
    desktop they run on. It takes screenshots with maim and drives the pointer, keyboard and
    windows with xdotool.

    Screenshots are scaled to Claude's image limits: at most 1568 pixels on the long edge and
    1.15 million pixels, set by `COMPUTER_USE_MAX_EDGE` and `COMPUTER_USE_MAX_PIXELS`. All tool
    coordinates use screenshot pixels. `zoom` captures a region at full resolution, `windows`
    and `focus_window` list and focus windows, and `actions` runs several steps in one call and
    returns a screenshot afterwards. Clicks, drags and scrolls accept held modifier keys.

    When the agent starts without `DISPLAY`, such as over SSH, the server uses the newest X
    server socket the user owns, for example an open xrdp session.
  '';
}
