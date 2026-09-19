# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{inputs, ...}: {
  flake = {
    nixosModules.shell-programs = {
      lib,
      config,
      pkgs,
      ...
    }: let
      cfg = config.custom.shell;
    in {
      config = lib.mkIf cfg.enable {
        preservation.preserveAt = lib.mkIf config.custom.preservation.enable {
          "/persist" = {
            users.${config.custom.user.name} = {
              directories = [
                ".local/share/atuin"
                ".local/share/zoxide"
                ".cache/tealdeer"
                ".local/share/nix-index"
                ".local/share/yazi"
                ".local/share/broot"
                ".cache/yazi"
                ".cache/carapace"
                ".config/carapace"
                ".local/share/direnv"
              ];
            };
          };
        };

        systemd = {
          tmpfiles.rules = [
            "L+ /bin/bash - - - - ${pkgs.bash}/bin/bash"
          ];
        };

        home-manager.users.${config.custom.user.name} = {pkgs, ...}: {
          imports = [
            inputs.nix-index-database.homeModules.nix-index
          ];

          programs = {
            nix-index-database.comma = {enable = true;};
            nix-index = {
              enable = true;
              package = pkgs.nix-index;
            };

            starship = {
              enable = true;
            };

            atuin = {
              enable = true;
            };

            eza = {
              enable = true;
              icons = "auto";
              git = true;
            };

            zoxide = {
              enable = true;
            };

            tealdeer = {
              enable = true;
              settings.updates.auto_update = true;
            };

            television = {
              enable = true;
            };

            pay-respects = {
              enable = true;
            };

            bat = {
              enable = true;
              extraPackages = with pkgs.bat-extras; [batdiff batgrep batman batwatch prettybat];
              config = {
                style = "plain";
              };
            };

            fd = {enable = true;};

            btop = {
              enable = true;
              settings = {vim_keys = true;};
            };

            fastfetch = {
              enable = true;
              settings = {
                display = {
                  separator = "  ";
                  color = "blue";
                };
                modules = [
                  {
                    type = "title";
                    key = "";
                    color = {
                      user = "blue";
                      at = "white";
                      host = "blue";
                    };
                  }
                  {
                    type = "os";
                    key = "󱄅";
                  }
                  {
                    type = "kernel";
                    key = "";
                  }
                  {
                    type = "uptime";
                    key = "󰅐";
                  }
                  "break"
                  {
                    type = "board";
                    key = "󱩊";
                  }
                  {
                    type = "cpu";
                    key = "";
                  }
                  {
                    type = "gpu";
                    key = "󰢮";
                  }
                  {
                    type = "memory";
                    key = "";
                    format = "{1} / {2}";
                  }
                  {
                    type = "disk";
                    key = "󰋊";
                    format = "{1} / {2} ({9})";
                  }
                  {
                    type = "display";
                    key = "󰍹";
                  }
                  "break"
                  {
                    type = "de";
                    key = "󰧨";
                  }
                  {
                    type = "wm";
                    key = "";
                  }
                  {
                    type = "shell";
                    key = "";
                  }
                  {
                    type = "terminal";
                    key = "";
                  }
                  {
                    type = "packages";
                    key = "󰏖";
                  }
                ];
              };
            };

            yazi = {
              enable = true;
            };
            nix-your-shell = {
              enable = true;
            };
            broot = {
              enable = true;
            };
            fzf = {
              enable = true;
              historyWidget.command = "";
            };
            carapace = {
              enable = true;
            };
            ripgrep = {
              enable = true;
            };
            devenv = {
              enable = true;
            };
            direnv = {
              nix-direnv.enable = true;
              enable = true;
            };
          };
          home = {
            packages = with pkgs; [
              ugrep
              trash-cli
            ];
            shellAliases = {
              cat = "bat --style=plain --pager=never";
              igrep = "ug -Q";
              te = "trash-empty";
              tp = "trash-put";
              tb = "nc termbin.com 9999";
            };
            sessionVariables = {
              PAGER = "${pkgs.bat}/bin/bat";
              MANPAGER = "sh -c 'col --no-backspaces --spaces | ${pkgs.bat}/bin/bat --language man'";
            };
          };
        };
      };
    };
  };
}
