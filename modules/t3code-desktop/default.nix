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
    }: {
      home.packages = [
        inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.t3code-desktop
      ];
    };
  };
  docs = ''
    Installs the T3 Code desktop app, which connects to local or remote T3 Code servers.
    Pair a remote server with a one-time link from `t3 pair` on that host, entered under
    **Settings → Environments → Add environment**. App state in `~/.config/t3code-v2` and
    `~/.t3` persists when preservation is enabled.
  '';
}
