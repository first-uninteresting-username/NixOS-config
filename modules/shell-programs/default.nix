# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "shell-programs";
  ids = ["shell"];
  state = {
    home.directories = [
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
  module = _: {
    nixos = {pkgs, ...}: {
      config = {
        systemd = {
          tmpfiles.rules = [
            "L+ /bin/bash - - - - ${pkgs.bash}/bin/bash"
          ];
        };
      };
    };
    home = {
      pkgs,
      inputs,
      ...
    }: {
      imports = [
        inputs.nix-index-database.homeModules.nix-index
      ];
      config = {
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
            shellWrapperName = "yy";
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
  checks = {
    mkHost,
    pkgs,
    system,
    ...
  }: let
    shellConfig = shell:
      (mkHost {
        name = "yazi-${shell}-fixture";
        role = "home";
        inherit system;
        ids = ["home-manager" "xdg" "shell" shell];
        args = {
          userName = "fixture";
          homeStateVersion = "26.11";
        };
      }).config.programs;
    zshConfig = shellConfig "zsh";
    nuConfig = shellConfig "nushell";
  in {
    yazi-integration =
      pkgs.runCommand "yazi-shell-integration" {
        nativeBuildInputs = [pkgs.python3 pkgs.zsh pkgs.nushell];
        zshSource = pkgs.writeText "yazi-zsh-init" zshConfig.zsh.initContent;
        nuSource = pkgs.writeText "yazi-nushell-init" nuConfig.nushell.extraConfig;
      } ''
        python3 ${./_checks/yazi-integration.py} "$zshSource" "$nuSource"
        touch "$out"
      '';
  };
  docs = ''
    Run `yy` in Zsh or Nushell to open Yazi. Browse to a directory and press `q`
    to change the parent shell's working directory to it. Paths with spaces work;
    for example, `yy "My Documents"` opens that directory.

    Run `yazi` directly when you want to keep the parent shell's working directory.
    The `shell` host ID installs Yazi; select `zsh` or `nushell` for shell integration.
  '';
}
