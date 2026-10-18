# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "nushell";
  ids = ["shell"];
  module = _: {
    nixos = {
      lib,
      pkgs,
      userName,
      preservationEnable,
      shell,
      ...
    }: let
      cfg = shell;
    in {
      config = lib.mkIf (cfg.enable
        && cfg.name
        == "nushell") {
        preservation.preserveAt = lib.mkIf preservationEnable {
          "/persist" = {
            users.${userName} = {
              directories = [
                ".local/share/nushell"
                ".cache/nushell"
              ];
            };
          };
        };

        users.users.${userName}.shell = pkgs.nushell;
        environment.shells = [pkgs.nushell];
      };
    };
    home = {
      shell,
      lib,
      ...
    }: let
      cfg = shell;
    in
      lib.mkIf (cfg.enable
        && cfg.name
        == "nushell") {
        programs = {
          nushell = {
            enable = true;
            extraConfig = ''
              def copyfile [file: path] {
                open $file | wl-copy
              }

              def copypath [] {
                $env.PWD | wl-copy
              }

              $env.TRANSIENT_PROMPT_COMMAND = { || starship module character }
              $env.TRANSIENT_PROMPT_COMMAND_RIGHT = ""
              $env.TRANSIENT_PROMPT_INDICATOR = ""
              $env.TRANSIENT_PROMPT_INDICATOR_VI_INSERT = ""
              $env.TRANSIENT_PROMPT_INDICATOR_VI_NORMAL = ""
              $env.TRANSIENT_PROMPT_MULTILINE_INDICATOR = ""
            '';
          };

          nix-index = {
            enableNushellIntegration = true;
          };
          starship = {
            enableNushellIntegration = true;
            settings = {
              add_newline = false;
              character = {
                success_symbol = "[❯](bold green)";
                error_symbol = "[❯](bold red)";
              };
            };
          };
          atuin = {enableNushellIntegration = true;};
          # tealdeer = {enableNushellIntegration = true;};
          television = {enableNushellIntegration = true;};
          pay-respects = {enableNushellIntegration = true;};
          yazi = {enableNushellIntegration = true;};
          nix-your-shell = {enableNushellIntegration = true;};
          broot = {enableNushellIntegration = true;};
          fzf = {enableNushellIntegration = true;};
          carapace = {enableNushellIntegration = true;};
          devenv = {enableNushellIntegration = true;};
          direnv = {enableNushellIntegration = true;};
        };
      };
  };
}
