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
      ".cache/blesh"
      ".local/state/blesh"
    ];
    home.files = [".bash_history"];
  };
  module = _: {
    nixos = {
      lib,
      pkgs,
      ...
    }: {
      config = {
        systemd = {
          tmpfiles.rules = [
            "L+ /bin/bash - - - - ${lib.getExe pkgs.bash}"
          ];
        };
      };
    };
    home = {
      pkgs,
      lib,
      inputs,
      ...
    }: {
      imports = [
        inputs.nix-index-database.homeModules.nix-index
      ];
      config = {
        programs = {
          # Interactive Bash for scripts and fallback use; Fish stays the login shell.
          bash = {
            enable = true;
            enableCompletion = true;
            historyControl = ["erasedups" "ignoreboth"];
            historySize = 10000;
            historyFileSize = 100000;
            shellOptions = [
              "histappend"
              "checkwinsize"
              "extglob"
              "globstar"
              "autocd"
              "cdspell"
              "dirspell"
            ];
            # Load ble.sh early without attaching; attach after all integrations, including zoxide.
            bashrcExtra = ''
              [[ $- == *i* ]] && source -- "${pkgs.blesh}/share/blesh/ble.sh" --attach=none
            '';
            initExtra = lib.mkMerge [
              ''
                bind 'set completion-ignore-case on'
                bind 'set show-all-if-ambiguous on'
                bind 'set colored-stats on'
                bind 'set mark-symlinked-directories on'
              ''
              (lib.mkOrder 2500 ''
                [[ ! ''${BLE_VERSION-} ]] || ble-attach
              '')
            ];
          };

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
            options = ["--cmd" "cd"];
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

          jq = {enable = true;};

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
            duf
            xh
          ];
          shellAliases = {
            cat = "bat --style=plain --pager=never";
            igrep = "ug -Q";
            te = "trash-empty";
            tp = "trash-put";
            tb = "nc termbin.com 9999";
          };
          sessionVariables = {
            PAGER = "${lib.getExe pkgs.bat}";
            MANPAGER = "sh -c 'col --no-backspaces --spaces | ${lib.getExe pkgs.bat} --language man'";
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
    fishConfig =
      (mkHost {
        name = "yazi-fish-fixture";
        role = "home";
        inherit system;
        ids = ["home-manager" "xdg" "shell" "fish"];
        args = {
          userName = "fixture";
          homeStateVersion = "26.11";
        };
      }).config.programs;
  in {
    yazi-integration =
      pkgs.runCommand "yazi-shell-integration" {
        nativeBuildInputs = [pkgs.python3 pkgs.fish];
        fishSource = pkgs.writeText "yazi-fish-init" ''
          function yy
          ${fishConfig.fish.functions.yy}
          end
        '';
      } ''
        python3 ${./_checks/yazi-integration.py} "$fishSource"
        touch "$out"
      '';
  };
  docs = ''
    Run `yy` in Fish or Bash to open Yazi. Browse to a directory and press `q`
    to change the parent shell's working directory to it. Paths with spaces work;
    for example, `yy "My Documents"` opens that directory.

    Run `yazi` directly when you want to keep the parent shell's working directory.
    The `shell` host ID installs Yazi; select `fish` for shell integration.
  '';
}
