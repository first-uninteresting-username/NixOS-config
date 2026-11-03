# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "t3code";
  ids = ["agents" "t3code"];
  state = {
    # Projects, threads, auth sessions, and settings.
    home.directories = [".t3"];
  };
  module = _: {
    nixos = {userName, ...}: {
      # Starts the user's T3 Code service at boot instead of at first login.
      users.users.${userName}.linger = true;
    };
    home = {
      config,
      inputs,
      lib,
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
      # The `t3` CLI mints pairing tokens for the running server.
      home.packages = [t3code];

      systemd.user.services.t3code = {
        Unit.Description = "T3 Code server";
        Service = {
          # Agent sessions need the user's agent CLIs, git, and other tools.
          Environment = [
            "PATH=${config.home.profileDirectory}/bin:/run/wrappers/bin:/run/current-system/sw/bin"
          ];
          # Without --base-dir, t3 keeps separate data per git worktree it runs in.
          ExecStart = lib.concatStringsSep " " [
            (lib.getExe t3code)
            "serve --host 127.0.0.1 --port 3773 --base-dir %h/.t3 %h/Agents"
          ];
          Restart = "on-failure";
        };
        Install.WantedBy = ["default.target"];
      };
    };
  };
  docs = ''
    Runs the T3 Code server, a web GUI for coding agents, as a user service on
    `127.0.0.1:3773`. The `agents` and `t3code` IDs together enable it; the server drives the
    agent CLIs that the `agents` module installs, not copies bundled with T3 Code; `opencode`
    runs the installed `opencode2`. User lingering starts the service at boot.
    Data in `~/.t3` persists when preservation is enabled.
  '';
  imperativeSteps = ''
    Forward the server port over SSH, then mint a one-time pairing link on the host:

    ```bash
    ssh -L 3773:localhost:3773 <host>
    t3 pair --base-dir ~/.t3
    ```

    Open the printed `http://127.0.0.1:3773/pair#token=...` link in a local browser.
  '';
}
