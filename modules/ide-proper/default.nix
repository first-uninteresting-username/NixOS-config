# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "ide-proper";
  ids = ["IDE" "ide-proper"];
  docs = ''
    Installs Gram, a Zed fork without AI features, which renders with the GPU. Hosts without a
    GPU select `ide-lite` instead. It requires the `IDE` host ID.

    Gram uses its built-in Nix support with `nil` and Alejandra formatting, Marksman and
    Prettier for Markdown, and the Hackatime extension for coding time. Extensions come from
    `nix-zed-extensions`, are built by Nix, and load from `GRAM_SYSTEM_EXTENSIONS_DIR`.
    `VISUAL` is `gram --wait`, and the **NixOS Config** launcher opens this repository in Gram.
  '';
  state = {
    home.directories = [
      ".config/gram"
      ".local/share/gram"
      ".cache/gram"
    ];
  };
  module = _: {
    home = {
      pkgs,
      config,
      inputs,
      ...
    }: let
      nixLogo = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
      configPath = "${config.xdg.userDirs.projects}/NixOS-config";
      zedExtensions =
        inputs.zed-extensions.legacyPackages.${pkgs.stdenv.hostPlatform.system}.zed-extensions;
    in {
      programs.gram = {
        enable = true;
        extensionPackages = with zedExtensions; [
          markdown-snippets
          marksman
          hackatime
          git-firefly
          log
        ];
        extraPackages = with pkgs; [
          nil
          nixd
          alejandra
          marksman
          wakatime-cli
          zed-wakatime-ls
        ];

        settings = {
          restore_on_startup = "last_session";
          vim_mode = false;
          autosave = "on_focus_change";
          autoscroll_on_clicks = true;
          middle_click_paste = false;
          show_whitespaces = "selection";

          title_bar = {
            show_menus = false;
            show_branch_name = true;
          };
          tab_bar.show = true;
          tabs = {
            file_icons = true;
            git_status = true;
          };
          toolbar = {
            breadcrumbs = true;
            quick_actions = true;
            selections_menu = true;
          };
          status_bar = {
            active_language_button = true;
            cursor_position_button = true;
            line_endings_button = false;
          };
          minimap = {
            show = "auto";
            thumb = "always";
          };
          diagnostics.button = true;
          file_finder.file_icons = true;
          search = {
            button = true;
            regex = true;
          };
          project_panel = {
            button = true;
            dock = "left";
            default_width = 240;
            file_icons = true;
            folder_icons = true;
          };
          outline_panel.dock = "left";

          prettier.allowed = true;

          lsp.nil.initialization_options.formatting.command = ["alejandra"];

          languages = {
            Markdown = {
              format_on_save = "on";
              formatter = "prettier";
            };
            Nix = {
              language_servers = ["nil" "!nixd" "..."];
              formatter.external = {
                command = "alejandra";
                arguments = ["--quiet" "--"];
              };
            };
          };
        };
      };

      home.sessionVariables.VISUAL = "gram --wait";

      xdg.desktopEntries = {
        "nixosconfig" = {
          name = "NixOS Config";
          comment = "Open Gram with the NixOS config";
          exec = "gram ${configPath}";
          icon = nixLogo;
          terminal = false;
          type = "Application";
          categories = ["Development" "IDE"];
        };
      };
    };
  };
}
