# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "t3code-desktop";
  ids = ["t3code-desktop"];
  state = {
    # Window state and saved environments, then the bundled local server's data.
    home.directories = [".config/t3code-v2" ".t3"];
  };
  module = _: {
    home = {
      inputs,
      pkgs,
      ...
    }: let
      # The upstream wrapper puts its own Codex, Claude Code, Cursor, Grok, and OpenCode first
      # in PATH. Drop them so T3 Code drives the agents the user already has installed.
      t3code = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.t3code.override {
        providerPackages = [
          # T3 Code runs `opencode`, but the agents module installs OpenCode 2 as `opencode2`.
          (pkgs.writeShellScriptBin "opencode" ''exec opencode2 "$@"'')
        ];
      };
    in {
      home.packages = [t3code.desktop];
    };
  };
  docs = ''
    Installs the T3 Code desktop app, which connects to local or remote T3 Code servers.
    Pair a remote server with a one-time link from `t3 pair` on that host, entered under
    **Settings → Environments → Add environment**. App state in `~/.config/t3code-v2` and
    `~/.t3` persists when preservation is enabled.
  '';
}
