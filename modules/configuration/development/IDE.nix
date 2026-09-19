# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
_: {
  flake = {
    nixosModules.IDE = {
      lib,
      config,
      ...
    }: {
      preservation.preserveAt = lib.mkIf config.custom.preservation.enable {
        "/persist" = {
          users.${config.custom.user.name} = {
            directories = [
              ".config/zed"
              ".local/share/zed"
              ".cache/zed"
              ".wakatime"

              ".config/Google"
              ".local/share/Google"
              ".android"
              ".gradle"
              ".cache/Google"
              ".java"

              "Android"
              ".m2"
              ".konan"
            ];
          };
        };
      };

      sops = {
        secrets = {
          "wakatime_api_key" = {};
          "MISTRAL_API_KEY" = {
            owner = config.custom.user.name;
          };
        };
        templates.".wakatime.cfg" = {
          content = ''
            [settings]
            api_url = https://hackatime.hackclub.com/api/hackatime/v1
            api_key = ${config.sops.placeholder.wakatime_api_key}
            heartbeat_rate_limit_seconds = 1
            sync_ai_disabled = true
          '';
          path = "${config.users.users.${config.custom.user.name}.home}/.wakatime.cfg";
          owner = config.custom.user.name;
          group = config.custom.user.name;
          mode = "0444";
        };
      };

      home-manager.users.${config.custom.user.name} = {
        pkgs,
        config,
        osConfig,
        ...
      }: let
        nixLogo = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
        configPath = "${config.xdg.userDirs.projects}/NixOS-config";
        keyFile = osConfig.sops.secrets."MISTRAL_API_KEY".path;
        zedPackage = pkgs.symlinkJoin {
          name = "zed-editor-env";
          paths = [pkgs.zed-editor];
          nativeBuildInputs = [pkgs.makeWrapper];
          postBuild = ''
            wrapProgram $out/bin/zeditor \
              --run '[ -r "${keyFile}" ] && export CODESTRAL_API_KEY="$(cat "${keyFile}")"'
          '';
        };
      in {
        programs = {
          micro = {
            enable = true;
          };

          zed-editor = {
            enable = true;
            package = zedPackage;
            extensions = [
              "nix"
              "markdown-snippets"
              "marksman"
              "hackatime"
              "git-firefly"
              "toml"
              "log"
            ];
            extraPackages = with pkgs; [
              nil
              alejandra
              marksman
              wakatime-cli
              zed-wakatime-ls
              nixd
            ];

            userSettings = {
              restore_on_startup = "last_session";

              vim_mode = false;
              disable_ai = false;
              show_edit_predictions = true;
              edit_predictions = {
                provider = "codestral";
              };
              agent = {
                enabled = false;
                button = false;
              };
              tabs = {
                file_icons = true;
                git_status = true;
              };
              tab_bar = {
                show = true;
              };
              title_bar = {
                show_menus = false;
                show_user_menu = true;
                show_sign_in = false;
                show_branch_name = true;
                show_branch_status_icon = false;
              };
              diagnostics = {
                button = true;
              };
              status_bar = {
                line_endings_button = false;
                cursor_position_button = true;
                active_language_button = true;
              };
              file_finder = {
                file_icons = true;
              };
              search = {
                button = true;
                regex = true;
              };
              middle_click_paste = false;
              show_whitespaces = "selection";
              toolbar = {
                agent_review = false;
                selections_menu = true;
                quick_actions = true;
                breadcrumbs = true;
              };
              minimap = {
                thumb = "always";
                show = "auto";
              };
              autoscroll_on_clicks = true;
              autosave = "on_focus_change";
              auto_update = false;
              default_open_behavior = "new_window";
              prettier = {
                allowed = true;
              };
              cli_default_open_behavior = "new_window";
              project_panel = {
                folder_icons = true;
                file_icons = true;
                default_width = 240.0;
                button = true;
                dock = "left";
              };
              outline_panel = {
                dock = "left";
              };
              collaboration_panel = {
                dock = "left";
              };

              lsp = {
                nil = {
                  initialization_options = {
                    formatting = {
                      command = ["alejandra"];
                    };
                  };
                };
              };

              languages = {
                Markdown = {
                  format_on_save = "on";
                  formatter = "prettier";
                  prettier = {
                    allowed = true;
                  };
                };

                Nix = {
                  language_servers = [
                    "nil"
                    "!nixd"
                    "..."
                  ];
                  formatter = {
                    external = {
                      command = "alejandra";
                      arguments = [
                        "--quiet"
                        "--"
                      ];
                    };
                  };
                };
              };
            };
          };
        };

        home = {
          packages = with pkgs; [
            nil
            alejandra
            wakatime-cli
          ];

          sessionVariables = {
            EDITOR = "micro";
            VISUAL = "zededitor --wait";
          };
          shellAliases = {
            canistopcoding = "wakatime-cli --today";
          };
        };

        xdg.desktopEntries = {
          "nixosconfig" = {
            name = "NixOS Config";
            comment = "Open zed with nixos config";
            exec = "${zedPackage}/bin/zeditor ${configPath}";
            icon = nixLogo;
            terminal = false;
            type = "Application";
            categories = ["Development" "IDE"];
          };
        };
      };
    };
  };
}
