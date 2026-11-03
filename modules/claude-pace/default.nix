# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "claude-pace";
  ids = ["GNOME" "agents"];
  packages = import ./_packages.nix;
  module = _: {
    home = {packages, ...}: {
      # Reads and refreshes the Claude Code login in ~/.claude, which the agents module persists.
      programs.gnome-shell = {
        enable = true;
        extensions = [{package = packages.default;}];
      };
    };
  };
}
