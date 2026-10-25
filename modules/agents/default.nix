# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "agents";
  ids = ["agents"];
  docs = ''
    Installs Claude Desktop and Claude Code and preserves their local configuration.
    Interactive Claude Code and OpenCode sessions started outside a directory tree containing
    an `AGENTS.md` open in `~/Agents` instead.
  '';
  imperativeSteps = ''
    Open Claude Desktop and follow the sign-in prompts.

    Start Claude Code in a terminal and follow the sign-in prompts:

    ```bash
    claude
    ```
  '';
  state = {
    home = {
      directories = [
        ".config/opencode"
        ".local/share/opencode"
        ".config/Claude"
        ".claude"
        "Agents"
      ];
      files = [
        ".claude.json"
      ];
    };
  };
  module = _: {
    home = {
      inputs,
      lib,
      pkgs,
      ...
    }: let
      llmAgents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};

      # Starts interactive sessions in ~/Agents unless the current directory or one of its
      # parents contains AGENTS.md. Invocations with subcommands, prompts, paths, or
      # print/help/version flags run unchanged.
      agentsFallback = ''
        if [ -t 0 ] && [ -t 1 ]; then
          agentsFallbackApplies=1
          for agentsFallbackArg in "$@"; do
            case $agentsFallbackArg in
              -p|--print|-h|--help|-v|--version) agentsFallbackApplies=0 ;;
              -*) ;;
              *) agentsFallbackApplies=0 ;;
            esac
          done
          agentsFallbackDir=$PWD
          while [ "$agentsFallbackApplies" = 1 ] && [ -n "$agentsFallbackDir" ]; do
            if [ -e "$agentsFallbackDir/AGENTS.md" ]; then
              agentsFallbackApplies=0
            fi
            agentsFallbackDir=''${agentsFallbackDir%/*}
          done
          if [ "$agentsFallbackApplies" = 1 ] && [ ! -e /AGENTS.md ]; then
            mkdir -p "$HOME/Agents"
            cd "$HOME/Agents"
          fi
        fi
      '';

      withAgentsFallback = package: name:
        pkgs.symlinkJoin {
          inherit (package) name;
          paths = [package];
          nativeBuildInputs = [pkgs.makeWrapper];
          postBuild = ''
            wrapProgram $out/bin/${name} --run ${lib.escapeShellArg agentsFallback}
          '';
          meta = package.meta or {};
        };
    in {
      programs = {
        opencode = {
          package = withAgentsFallback llmAgents.opencode "opencode";
          enable = true;
        };
        claude-code = {
          enable = true;
          package = withAgentsFallback llmAgents.claude-code "claude";
        };
      };

      home.packages = [
        llmAgents.ccusage
        llmAgents.claude-desktop
      ];
    };
  };
}
