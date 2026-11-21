# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "agents";
  ids = ["agents"];
  docs = ''
    Installs Claude Desktop and Claude Code and preserves their local configuration.
    Claude Code and OpenCode started from a terminal outside a directory tree containing an
    `AGENTS.md` open in `~/Agents` instead, whatever other arguments are given, including
    prompts and subcommands. Pass `--here` to either command to stay in the current directory,
    for example with a relative OpenCode directory argument. Claude Code's `-p`/`--print` also
    stays. The wrapper removes `--here` before starting the agent.
    Both agents load the MCP servers that other modules declare in `programs.mcp.servers`.
    In `~/Agents` and its subdirectories, both agents run tools without permission prompts:
    Claude Code starts in bypass permissions mode unless another permission mode is passed,
    and OpenCode interactive and `run` sessions auto-approve permissions that are not
    explicitly denied. Other directories keep the default permission behavior.
  '';
  # Runs the Claude Code fallback in a pseudo-terminal and checks where each invocation starts.
  checks = {
    pkgs,
    lib,
    ...
  }: {
    claude-fallback = import ./_checks/fallback.nix {
      inherit pkgs;
      fallback = import ./_fallback.nix {
        inherit lib;
        stayFlags = ["-p" "--print"];
      };
    };
  };
  imperativeSteps = ''
    Open Claude Desktop and follow the sign-in prompts.

    Start Claude Code in a terminal and follow the sign-in prompts:

    ```bash
    claude
    ```

    Turn off OpenCode 2 session tabs by adding this to `~/.config/opencode/cli.json`:

    ```json
    "tabs": {
      "mode": "off"
    }
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

      claudeFallback = import ./_fallback.nix {
        inherit lib;
        stayFlags = ["-p" "--print"];
      };

      opencodeFallback = import ./_fallback.nix {inherit lib;};

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

      # The WakaTime Claude Code plugin runs its hooks with NODE_BIN when set; without it, each
      # hook falls back to `nix run nixpkgs#nodejs`.
      claudeNode = ''
        export NODE_BIN="''${NODE_BIN:-${lib.getExe pkgs.nodejs}}"
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

      withAgentsFallback = package: name: fallback: extraRun:
        pkgs.symlinkJoin {
          inherit (package) name;
          paths = [package];
          nativeBuildInputs = [pkgs.makeWrapper];
          postBuild = ''
            wrapProgram $out/bin/${name} \
              --run ${lib.escapeShellArg (fallback + extraRun)}
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
          package = withAgentsFallback llmAgents.opencode2 "opencode2" opencodeFallback opencodeAuto;
          enable = true;
          enableMcpIntegration = true;
        };
        claude-code = {
          enable = true;
          package =
            withAgentsFallback llmAgents.claude-code "claude" claudeFallback
            (claudeBypass + claudeNode);
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
