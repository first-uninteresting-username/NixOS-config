# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "ide-lite";
  ids = ["IDE" "ide-lite"];
  docs = ''
    Installs Kate configured to match `ide-proper` (Zed) where Kate allows. Kate renders on
    the CPU, so it stays responsive on hosts without a GPU, such as xrdp sessions.
    It requires the `IDE` host ID.

    - Language servers: `nil` for Nix, with Alejandra formatting, and Marksman for Markdown.
      Both are pre-approved, so Kate starts them without a prompt. Semantic highlighting,
      inlay hints, hover, and signature help are on.
    - Formatting on save: Alejandra for Nix through the format plugin, and Prettier for
      Markdown through a before-save external tool.
    - Coding time: the packaged [kate-wakatime](https://github.com/Tatsh/kate-wakatime) plugin
      sends heartbeats through `wakatime-cli` on edits and saves, using the `IDE` module's
      Hackatime configuration.
    - Interface: last-session restore, minimap, breadcrumbs, indent guides, trailing-space
      markers, and a hidden menu bar. The project, file tree, search, terminal, git blame,
      build, snippets, color picker, and Markdown preview plugins are enabled.

    `VISUAL` is `kate --block`, and the **NixOS Config** launcher opens this repository in Kate.

    Kate rewrites its configuration files at runtime, so activation merges the managed keys
    into `katerc` and enables the plugins in every saved session. Settings changed in Kate's
    dialog persist until the next activation resets a managed key.

    Kate has no inline AI edit predictions or agent panel; run an agent CLI in the terminal
    panel instead. Kate runs one language server per language, so `nixd` does not run
    beside `nil`.
  '';
  state = {
    home.directories = [
      ".local/share/kate"
      ".local/state/kate"
      ".cache/kate"
    ];
    home.files = [
      ".config/katerc"
      ".config/katemetainfos"
      ".config/kate-externaltoolspluginrc"
    ];
  };
  packages = {pkgs, ...}: {
    kate-wakatime = pkgs.stdenv.mkDerivation (finalAttrs: {
      pname = "kate-wakatime";
      version = "1.5.5";
      src = pkgs.fetchFromGitHub {
        owner = "Tatsh";
        repo = "kate-wakatime";
        tag = "v${finalAttrs.version}";
        hash = "sha256-uQOyzUEUxaIuNAJ+VzFY8h9lcukY47dPasffoBGQ3J4=";
      };
      nativeBuildInputs = [pkgs.cmake pkgs.kdePackages.extra-cmake-modules];
      buildInputs = with pkgs.kdePackages; [qtbase ki18n kcoreaddons ktexteditor];
      cmakeFlags = ["-DBUILD_TESTING=OFF"];
      # A KTextEditor plugin loaded by Kate's own wrapped binary.
      dontWrapQtApps = true;
      passthru.updateScript = pkgs.nix-update-script {extraArgs = ["--flake"];};
      meta = {
        description = "WakaTime heartbeats from Kate and other KTextEditor apps";
        homepage = "https://github.com/Tatsh/kate-wakatime";
        license = pkgs.lib.licenses.mit;
        platforms = pkgs.lib.platforms.linux;
      };
    });
  };
  checks = {
    pkgs,
    packages,
    ...
  }: {
    # Kate discovers KTextEditor plugins only in this namespace; upstream has moved it before.
    kate-wakatime-plugin-path = pkgs.runCommand "kate-wakatime-plugin-path" {} ''
      test -f ${packages.kate-wakatime}/lib/qt-6/plugins/kf6/ktexteditor/ktexteditor_wakatime.so
      touch "$out"
    '';
  };
  module = _: {
    home = {
      lib,
      pkgs,
      config,
      packages,
      ...
    }: let
      kde = pkgs.kdePackages;
      nixLogo = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
      configPath = "${config.xdg.userDirs.projects}/NixOS-config";
      alejandra = ["${pkgs.alejandra}/bin/alejandra" "--quiet" "-"];
      prettier = "${pkgs.prettier}/bin/prettier";

      # Kate loads the terminal panel and Markdown preview as KParts from QT_PLUGIN_PATH.
      # The WakaTime plugin finds wakatime-cli through PATH.
      katePackage = pkgs.symlinkJoin {
        name = "kate-ide-lite";
        paths = [kde.kate];
        nativeBuildInputs = [pkgs.makeWrapper];
        postBuild = ''
          for bin in kate kwrite; do
            wrapProgram $out/bin/$bin \
              --prefix QT_PLUGIN_PATH : ${lib.makeSearchPath "lib/qt-6/plugins" [
            kde.konsole
            kde.markdownpart
            packages.kate-wakatime
          ]} \
              --prefix PATH : ${lib.makeBinPath [pkgs.wakatime-cli]}
          done
        '';
      };

      # Kate starts only servers whose resolved command line is on its allow list, so servers
      # use store paths and the same strings are pre-approved below.
      servers = {
        nix = {
          command = ["${pkgs.nil}/bin/nil"];
          url = "https://github.com/oxalica/nil";
          highlightingModeRegex = "^Nix$";
          settings.nil.formatting.command = alejandra;
        };
        markdown = {
          command = ["${pkgs.marksman}/bin/marksman" "server"];
          url = "https://github.com/artempyanykh/marksman";
          highlightingModeRegex = "^Markdown$";
        };
      };
      allowedServers = lib.mapAttrsToList (_: s: lib.concatStringsSep " " s.command) servers;

      externalTools = {
        # Kate's formatter plugin has no Markdown formatter; Zed runs Prettier on save.
        prettier-markdown = {
          name = "Prettier (Markdown)";
          category = "Format";
          executable = prettier;
          arguments = "--stdin-filepath %{Document:FileName}";
          input = "%{Document:Text}";
          workingDir = "%{Document:Path}";
          mimetypes = "text/markdown";
          output = "ReplaceCurrentDocument";
          save = "None";
          trigger = "BeforeSave";
          reload = false;
        };
      };

      kateSettings = {
        General = {
          "Startup Session" = "last";
          "Restore Window Configuration" = true;
          "Show Url Nav Bar" = true;
          "Show Symbol In Navigation Bar" = true;
          "Open New Tab To The Right Of Current" = true;
          "Show Menu Bar" = false;
        };
        lspclient = {
          AllowedServerCommandLines = lib.concatStringsSep "," allowedServers;
          SemanticHighlighting = true;
          InlayHints = true;
          AutoHover = true;
          SignatureHelp = true;
          ShowCompletions = true;
          CompletionDocumentation = true;
          Diagnostics = true;
          HighlightSymbol = true;
          SymbolTree = true;
          # The format plugin formats on save; LSP formatting would run a second time.
          FormatOnSave = false;
        };
        "KTextEditor View" = {
          "Line Numbers" = true;
          "Scroll Bar MiniMap" = true;
          "Scroll Past End" = true;
          "Auto Completion" = true;
          "Show Documentation With Completion" = true;
          "Bracket Match Preview" = true;
        };
        "KTextEditor Renderer" = {
          "Show Indentation Lines" = true;
          "Show Whole Bracket Expression" = true;
        };
        "KTextEditor Document" = {
          "Auto Save On Focus Out" = true;
          # 1 = trailing whitespace only, the closest match to Zed's "selection".
          "Show Spaces" = 1;
        };
      };

      # Kate keeps plugin selection per session, not in katerc.
      kateSessionSettings = {
        "Kate Plugins" = lib.genAttrs [
          "lspclientplugin"
          "formatplugin"
          "kateprojectplugin"
          "katefiletreeplugin"
          "katesearchplugin"
          "katekonsoleplugin"
          "kategitblameplugin"
          "katebuildplugin"
          "katesnippetsplugin"
          "katecolorpickerplugin"
          "ktexteditorpreviewplugin"
          "externaltoolsplugin"
          "tabswitcherplugin"
          "openlinkplugin"
          "ktexteditor_wakatime"
        ] (_: true);
      };

      # `file` is a shell word, so callers can pass a loop variable.
      writeKateConfig = file: groups:
        lib.concatStrings (lib.flatten (lib.mapAttrsToList (group: entries:
          lib.mapAttrsToList (key: value: ''
            run ${kde.kconfig}/bin/kwriteconfig6 --file ${file} \
              --group ${lib.escapeShellArg group} --key ${lib.escapeShellArg key} \
              ${lib.optionalString (lib.isBool value) "--type bool"} \
              ${lib.escapeShellArg (
              if lib.isBool value
              then lib.boolToString value
              else toString value
            )}
          '')
          entries)
        groups));
    in {
      home = {
        packages = [
          katePackage
          pkgs.marksman
          pkgs.prettier
        ];
        sessionVariables.VISUAL = "kate --block";

        # Kate rewrites katerc at runtime, so merge managed keys instead of linking the file.
        activation.kateSettings = lib.hm.dag.entryAfter ["writeBoundary"] (
          writeKateConfig (lib.escapeShellArg "${config.xdg.configHome}/katerc") kateSettings
          # Skip seeding Kate's example tools, which would hide the managed ones on first start.
          + writeKateConfig (lib.escapeShellArg "${config.xdg.configHome}/kate-externaltoolspluginrc") {
            Global.firststart = false;
          }
          + ''
            kateData=${lib.escapeShellArg "${config.xdg.dataHome}/kate"}
            run mkdir -p "$kateData/sessions"
            for kateSession in "$kateData/anonymous.katesession" "$kateData"/sessions/*.katesession; do
              [ -e "$kateSession" ] || [ "$kateSession" = "$kateData/anonymous.katesession" ] || continue
              ${writeKateConfig "\"$kateSession\"" kateSessionSettings}
            done
          ''
        );
      };

      xdg.configFile =
        {
          "kate/lspclient/settings.json".text = builtins.toJSON {inherit servers;};
          "kate/formatting/settings.json".text = builtins.toJSON {
            formatOnSave = true;
            # Kate formats Nix through its `nixfmt` entry; point it at Alejandra like Zed.
            nixfmt.command = alejandra;
            prettier.command = [prettier];
          };
        }
        // lib.mapAttrs' (name: tool:
          lib.nameValuePair "kate/externaltools/${name}" {
            text = lib.generators.toINI {} {
              General = tool // {actionName = "externaltool_${name}";};
            };
          })
        externalTools;

      xdg.desktopEntries."nixosconfig" = {
        name = "NixOS Config";
        comment = "Open Kate with nixos config";
        exec = "${katePackage}/bin/kate ${configPath}";
        icon = nixLogo;
        terminal = false;
        type = "Application";
        categories = ["Development" "IDE"];
      };
    };
  };
}
