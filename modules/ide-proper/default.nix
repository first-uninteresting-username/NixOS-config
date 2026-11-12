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
    Prettier for Markdown, basedpyright and Ruff for Python, and the Hackatime extension for
    coding time. Hackatime runs `hackatime-ls`, its fork of the WakaTime language server,
    packaged here, with `wakatime-cli` from the `wakatime` module.

    Gram never downloads language servers. Global ones come from Nix; project-specific ones
    (such as rust-analyzer) come from the project's devenv, which Gram loads through direnv and
    prefers over the global ones. Extensions come from `nix-zed-extensions`, are built by Nix,
    and load from `GRAM_SYSTEM_EXTENSIONS_DIR`. Activation deletes Gram's extension index so
    Gram rebuilds it on the next start; otherwise the store path's epoch mtime keeps a stale
    index forever.
    `VISUAL` is `gram --wait`, and the **NixOS Config** launcher opens this repository in Gram.

    The REPL (`repl: run`) uses a Python 3 Jupyter kernel with `ipykernel`. Projects that need
    other packages register their own kernel from a virtual environment.

    It also installs the Godot editor. The GDScript extension talks to the language server of
    a running Godot editor on port 6005 through `nc`, so open the project in Godot before
    editing its scripts in Gram. To open scripts from Godot in Gram, set **Editor Settings >
    Text Editor > External** to `gram` with the arguments `{project} {file}:{line}:{col}`.
  '';
  state = {
    home.directories = [
      ".config/gram"
      ".local/share/gram"
      ".cache/gram"
      ".config/godot"
      ".local/share/godot"
      ".cache/godot"
    ];
  };
  packages = {pkgs, ...}: {
    # The Hackatime extension runs the first `wakatime-ls` on PATH; nixpkgs only packages
    # upstream WakaTime's server, so build the fork the extension ships.
    hackatime-ls = pkgs.rustPlatform.buildRustPackage (finalAttrs: {
      pname = "hackatime-ls";
      version = "0.4.0";
      src = pkgs.fetchFromGitHub {
        owner = "espcaa";
        repo = "zed-hackatime";
        tag = "v${finalAttrs.version}";
        hash = "sha256-lLC/MzZPYiJJhGnVTS50oEr4zmjTpgbRP2ZS7v/ceA4=";
      };
      buildAndTestSubdir = "wakatime-ls";
      cargoHash = "sha256-VkoxCloiYenhKQqAQvx4FnTKzznFsqe2Qv0gr1ftahg=";
      passthru.updateScript = pkgs.nix-update-script {extraArgs = ["--flake"];};
      meta = {
        description = "Hackatime fork of the WakaTime language server for Zed and Gram";
        homepage = "https://github.com/espcaa/zed-hackatime";
        license = pkgs.lib.licenses.mit;
        mainProgram = "wakatime-ls";
      };
    });
  };
  module = _: {
    home = {
      lib,
      pkgs,
      config,
      inputs,
      packages,
      ...
    }: let
      nixLogo = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
      configPath = "${config.xdg.userDirs.projects}/NixOS-config";
      # Upstream's overlay reads `"${prev.path}/…"`, which copies nixpkgs into the store and
      # fails under read-only evaluation (`nix flake check --no-build`). Redefine that helper
      # with path concatenation so evaluation never needs the copy.
      zedExtensions =
        (pkgs.appendOverlays [
          inputs.zed-extensions.overlays.default
          (_: prev: {
            fetch-cargo-vendor-util = prev.writers.writePython3Bin "fetch-cargo-vendor-util" {
              libraries = with prev.python3Packages;
                [
                  requests
                  tomli-w
                ]
                ++ requests.optional-dependencies.socks;
              flakeIgnore = ["E501"];
            } (builtins.readFile (prev.path + "/pkgs/build-support/rust/fetch-cargo-vendor-util.py"));
          })
        ]).zed-extensions;
      kernelPython = pkgs.python3.withPackages (ps: [ps.ipykernel]);
    in {
      # Gram's REPL runs Jupyter kernels and finds them in the Jupyter data directory.
      xdg.dataFile."jupyter/kernels/python3/kernel.json".text = builtins.toJSON {
        argv = [
          (lib.getExe kernelPython)
          "-m"
          "ipykernel_launcher"
          "-f"
          "{connection_file}"
        ];
        display_name = "Python 3";
        language = "python";
      };

      programs.gram = {
        enable = true;
        extensionPackages = with zedExtensions; [
          markdown-snippets
          marksman
          hackatime
          git-firefly
          log
          gdscript
        ];
        extraPackages = with pkgs; [
          nil
          nixd
          alejandra
          marksman
          basedpyright
          ruff
          wakatime-cli
          packages.hackatime-ls
          # The GDScript extension bridges to Godot's language server with `nc`.
          netcat
        ];

        settings = {
          restore_on_startup = "last_session";
          vim_mode = false;
          autosave = "on_focus_change";
          autoscroll_on_clicks = true;
          middle_click_paste = false;
          show_whitespaces = "selection";
          # Gram's Linux text system defaults to grayscale antialiasing; Zed
          # defaults to subpixel, which renders the same fonts noticeably crisper.
          text_rendering_mode = "subpixel";
          # Gram's defaults disable `calt`, which turns off programming ligatures such as `==`
          # and `->`; Zed leaves it enabled.
          buffer_font_features.calt = true;

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

      # Gram rebuilds its extension index only when the index is older than an extension
      # directory, but `GRAM_SYSTEM_EXTENSIONS_DIR` is a store path with the epoch mtime, so a
      # stale index (for example, one written before the directory existed) never refreshes and
      # Nix-provided extensions such as Hackatime never load. Drop the index so Gram rebuilds it.
      home.activation.gramExtensionIndex = lib.hm.dag.entryAfter ["writeBoundary"] ''
        run rm -f "${config.xdg.dataHome}/gram/extensions/index.json"
      '';

      home.packages = [pkgs.godot];

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
