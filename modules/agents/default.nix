# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "agents";
  ids = ["agents"];
  docs = "Installs Claude Desktop and Claude Code and preserves their local configuration.";
  imperativeSteps = ''
    Open Claude Desktop and follow the sign-in prompts.

    Start Claude Code in a terminal and follow the sign-in prompts:

    ```bash
    claude
    ```
  '';
  module = _: {
    nixos = {
      lib,
      userName,
      preservationEnable,
      ...
    }: {
      preservation.preserveAt = lib.mkIf preservationEnable {
        "/persist" = {
          users.${userName} = {
            directories = [
              ".config/opencode"
              ".local/share/opencode"
              ".config/kilocode"
              ".config/Claude"
              ".claude"
            ];
            files = [".claude.json"];
          };
        };
      };
    };
    home = {
      inputs,
      pkgs,
      ...
    }: {
      programs = {
        opencode = {
          package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
          enable = true;
        };
      };

      home.packages = with inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}; [
        kilocode-cli
        ccusage
        claude-desktop
        claude-code
      ];
    };
  };
}
