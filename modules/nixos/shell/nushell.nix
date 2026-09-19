# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
_: {
  flake = {
    nixosModules.nushell = {
      lib,
      pkgs,
      config,
      ...
    }: let
      cfg = config.custom.shell;
    in {
      config = lib.mkIf (cfg.enable
        && cfg.name
        == "nushell") {
        preservation.preserveAt = lib.mkIf config.custom.preservation.enable {
          "/persist" = {
            users.${config.custom.user.name} = {
              directories = [
                ".local/share/nushell"
                ".cache/nushell"
              ];
            };
          };
        };

        users.users.${config.custom.user.name}.shell = pkgs.nushell;
        environment.shells = [pkgs.nushell];

        home-manager.users.${config.custom.user.name} = _: {
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
    };
  };
}
