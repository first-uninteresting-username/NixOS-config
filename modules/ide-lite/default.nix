# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
# Kate configured to match `ide-proper` (Zed) as closely as Kate allows. Kate renders on the CPU,
# so it stays usable on hosts without a GPU, such as xrdp sessions.
{mkModule, ...}:
mkModule {
  name = "ide-lite";
  ids = ["IDE" "ide-lite"];
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
  module = _: {
    home = {
      lib,
      pkgs,
      config,
      ...
    }: let
      kde = pkgs.kdePackages;
      nixLogo = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
      configPath = "${config.xdg.userDirs.projects}/NixOS-config";
      alejandra = ["${pkgs.alejandra}/bin/alejandra" "--quiet" "-"];
      prettier = "${pkgs.prettier}/bin/prettier";

      # Kate loads the terminal panel and Markdown preview as KParts from QT_PLUGIN_PATH.
      katePackage = pkgs.symlinkJoin {
        name = "kate-ide-lite";
        paths = [kde.kate];
        nativeBuildInputs = [pkgs.makeWrapper];
        postBuild = ''
          for bin in kate kwrite; do
            wrapProgram $out/bin/$bin --prefix QT_PLUGIN_PATH : ${lib.makeSearchPath
            "lib/qt-6/plugins" [kde.konsole kde.markdownpart]}
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

      # Save-triggered tools fire only for listed MIME types; Kate matches them exactly.
      codeMimeTypes = [
        "text/plain"
        "text/x-nix"
        "text/markdown"
        "text/x-python"
        "text/x-python3"
        "text/x-shellscript"
        "application/x-shellscript"
        "application/x-fishscript"
        "application/toml"
        "application/yaml"
        "application/json"
        "text/rust"
        "text/x-go"
        "text/javascript"
        "application/javascript"
        "application/x-typescript"
        "text/x-csrc"
        "text/x-chdr"
        "text/x-c++src"
        "text/x-c++hdr"
        "text/x-kotlin"
        "text/x-java"
        "text/x-lua"
        "text/css"
        "text/html"
        "text/x-cmake"
        "text/x-qml"
        "application/vnd.dart"
      ];

      externalTools = {
        # Zed's hackatime extension sends a heartbeat per edit; Kate can only hook saves, which
        # auto-save on focus loss makes frequent.
        wakatime = {
          name = "WakaTime heartbeat";
          category = "WakaTime";
          executable = "${pkgs.wakatime-cli}/bin/wakatime-cli";
          arguments = lib.concatStringsSep " " [
            "--entity %{Document:FilePath}"
            "--write"
            "--plugin \"kate/${kde.kate.version} kate-ide-lite/1.0\""
          ];
          workingDir = "%{Document:Path}";
          mimetypes = lib.concatStringsSep ";" codeMimeTypes;
          output = "Ignore";
          save = "None";
          trigger = "AfterSave";
          reload = false;
        };
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
        ] (_: true);
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

      writeKateConfig = file: groups:
        lib.concatStrings (lib.flatten (lib.mapAttrsToList (group: entries:
          lib.mapAttrsToList (key: value: ''
            run ${kde.kconfig}/bin/kwriteconfig6 --file ${lib.escapeShellArg file} \
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
          writeKateConfig "${config.xdg.configHome}/katerc" kateSettings
          # Skip seeding Kate's example tools, which would hide the managed ones on first start.
          + writeKateConfig "${config.xdg.configHome}/kate-externaltoolspluginrc" {
            Global.firststart = false;
          }
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
