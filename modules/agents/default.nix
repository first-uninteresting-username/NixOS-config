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
    an `AGENTS.md` open in `~/Agents` instead. Pass `--here` to either command to stay in the
    current directory; the wrapper removes the flag before starting the agent.
    Both agents load the MCP servers that other modules declare in `programs.mcp.servers`.
    In `~/Agents` and its subdirectories, both agents run tools without permission prompts:
    Claude Code starts in bypass permissions mode unless another permission mode is passed,
    and OpenCode interactive and `run` sessions auto-approve permissions that are not
    explicitly denied. Other directories keep the default permission behavior.
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
      # print/help/version flags run unchanged. The wrapper-only --here flag is removed from the
      # arguments and keeps the current directory.
      agentsFallback = ''
        agentsFallbackApplies=1
        agentsFallbackCount=$#
        while [ "$agentsFallbackCount" -gt 0 ]; do
          agentsFallbackArg=$1
          shift
          if [ "$agentsFallbackArg" = --here ]; then
            agentsFallbackApplies=0
          else
            set -- "$@" "$agentsFallbackArg"
          fi
          agentsFallbackCount=$((agentsFallbackCount - 1))
        done
        if [ -t 0 ] && [ -t 1 ]; then
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

      inAgentsWorkspace = ''
        agentsBypassApplies=0
        case $PWD/ in
          "$HOME/Agents/"*) agentsBypassApplies=1 ;;
        esac
      '';

      # Claude Code ignores bypassPermissions in project settings, so the wrapper passes the
      # mode when the session runs in ~/Agents. Root flags are also accepted before subcommands.
      claudeBypass =
        inAgentsWorkspace
        + ''
          for agentsBypassArg in "$@"; do
            case $agentsBypassArg in
              --permission-mode|--permission-mode=*|--dangerously-skip-permissions)
                agentsBypassApplies=0
                ;;
            esac
          done
          if [ "$agentsBypassApplies" = 1 ]; then
            set -- --permission-mode bypassPermissions "$@"
          fi
        '';

      # OpenCode 2 accepts --auto on the root command and on run. Placing it before another
      # subcommand breaks argument parsing, so other subcommands run unchanged.
      opencodeAuto =
        inAgentsWorkspace
        + ''
          agentsBypassCommand=
          for agentsBypassArg in "$@"; do
            case $agentsBypassArg in
              --auto) agentsBypassApplies=0 ;;
              -*) ;;
              *)
                if [ -z "$agentsBypassCommand" ]; then
                  agentsBypassCommand=$agentsBypassArg
                fi
                ;;
            esac
          done
          if [ "$agentsBypassApplies" = 1 ]; then
            case $agentsBypassCommand in
              run) set -- "$@" --auto ;;
              upgrade|update|uninstall|acp|api|debug|auth|mcp|plugin|models|stats|mini) ;;
              session|service|reload|pair|serve) ;;
              *) set -- --auto "$@" ;;
            esac
          fi
        '';

      withAgentsFallback = package: name: extraRun:
        pkgs.symlinkJoin {
          inherit (package) name;
          paths = [package];
          nativeBuildInputs = [pkgs.makeWrapper];
          postBuild = ''
            wrapProgram $out/bin/${name} \
              --run ${lib.escapeShellArg (agentsFallback + extraRun)}
          '';
          # Keeps passthru attributes, such as OpenCode's jsonschema, visible to Home Manager.
          passthru = package.passthru or {};
          meta = package.meta or {};
        };

      agentsGuide = ''
        # Agents workspace

        You are working on a NixOS system managed declaratively from a Nix flake.

        - Save files you are working on in this directory (`~/Agents`). It is your local workspace
          and persists across reboots.
        - Do not install software imperatively. System and user configuration changes belong in the
          NixOS configuration.
        - Create persistent skills in the NixOS configuration, not in `~/.claude` or
          `~/.config/opencode`, so they are managed declaratively.
        - The NixOS configuration lives in `./NixOS-config`. If it is missing, clone it:

        ```bash
        gh repo clone NixOS-config
        ```

        Read `NixOS-config/AGENTS.md` before changing the configuration.
      '';
    in {
      home.file."Agents/AGENTS.md".text = agentsGuide;

      programs = {
        opencode = {
          package = withAgentsFallback llmAgents.opencode2 "opencode2" opencodeAuto;
          enable = true;
          enableMcpIntegration = true;
        };
        claude-code = {
          enable = true;
          package = withAgentsFallback llmAgents.claude-code "claude" claudeBypass;
          enableMcpIntegration = true;
        };
      };

      home.packages = [
        llmAgents.ccusage
        llmAgents.claude-desktop
      ];
    };
  };
}
