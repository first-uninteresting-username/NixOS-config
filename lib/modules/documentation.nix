# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  lib,
  pkgs,
  name,
  pages,
  commonArgs,
  state,
}: let
  reference = import ./argument-reference.nix {inherit lib pkgs commonArgs;};
  instructions = lib.filterAttrs (_: page: page.imperativeSteps != null) pages;
  # Attribute-set entries name their path and list the remaining upstream settings.
  describe = field: entry:
    if builtins.isString entry
    then "- `${entry}`"
    else let
      settings = builtins.removeAttrs entry [field];
      render = value:
        if builtins.isString value
        then value
        else builtins.toJSON value;
    in
      "- `${entry.${field}}`"
      + lib.optionalString (settings != {})
      " (${lib.concatStringsSep ", " (lib.mapAttrsToList (name: value: "${name}: ${render value}") settings)})";
  stateLists = moduleName:
    builtins.filter (list: list.entries != []) [
      {
        title = "System directories";
        field = "directory";
        entries = state.nixos.${moduleName}.directories or [];
      }
      {
        title = "System files";
        field = "file";
        entries = state.nixos.${moduleName}.files or [];
      }
      {
        title = "Home directories";
        field = "directory";
        entries = state.home.${moduleName}.directories or [];
      }
      {
        title = "Home files";
        field = "file";
        entries = state.home.${moduleName}.files or [];
      }
    ];
  stateModules = builtins.filter (moduleName: stateLists moduleName != []) (builtins.attrNames (state.nixos // state.home));
  statePage = pkgs.writeText "state.md" ''
    # State

    Selected modules declare this state. System paths are absolute; home paths are relative
    to the user's home directory. A selected persistence module decides where it is kept.

    ${
      if stateModules == []
      then "No selected modules declare state."
      else
        lib.concatMapStringsSep "\n\n" (moduleName:
          "## ${moduleName}\n\n"
          + lib.concatMapStringsSep "\n\n" (list: "### ${list.title}\n\n${lib.concatMapStringsSep "\n" (describe list.field) list.entries}")
          (stateLists moduleName))
        stateModules
    }
  '';
  # The caller omits blank pages; only selected modules with content get navigation.
  moduleFiles =
    lib.mapAttrsToList (moduleName: page: {
      name = "modules/${moduleName}.md";
      path = pkgs.writeText "${moduleName}.md" ''
        # ${moduleName}

        ${lib.optionalString (page.docs != null) "## Module docs\n\n${page.docs}\n"}
        ${lib.optionalString (page.imperativeSteps != null) "## Imperative steps\n\n${page.imperativeSteps}\n"}
      '';
    })
    pages;
  index = pkgs.writeText "index.md" ''
    # ${name} documentation

    This site contains documentation for modules selected by this host's IDs.
    Opening it does not execute the manual instructions.

    - [Imperative steps](imperative-steps.md)
    - [State](state.md)
    - [Common argument reference](module-reference.md)

    ## Modules

    ${
      if pages == {}
      then "No selected modules supply documentation."
      else lib.concatMapStringsSep "\n" (moduleName: "- [${moduleName}](modules/${moduleName}.md)") (builtins.attrNames pages)
    }
  '';
  combined = pkgs.writeText "imperative-steps.md" ''
    # Imperative steps

    ${
      if instructions == {}
      then "No selected modules supply imperative steps."
      else lib.concatStringsSep "\n\n" (lib.mapAttrsToList (moduleName: page: "## ${moduleName}\n\n${page.imperativeSteps}") instructions)
    }
  '';
  config = (pkgs.formats.toml {}).generate "zensical.toml" {
    project = {
      site_name = "${name} documentation";
      docs_dir = "docs";
      site_dir = "site";
      use_directory_urls = false;
      # Search workers require HTTP; these sites open directly from local files.
      plugins.search.enabled = false;
      theme.font = false;
      theme.favicon = "assets/nixos-logo.png";
      theme.palette = [
        {
          media = "(prefers-color-scheme: light)";
          scheme = "default";
          toggle = {
            icon = "lucide/sun";
            name = "Switch to dark mode";
          };
        }
        {
          media = "(prefers-color-scheme: dark)";
          scheme = "slate";
          toggle = {
            icon = "lucide/moon";
            name = "Switch to light mode";
          };
        }
      ];
      nav =
        [
          {Home = "index.md";}
          {"Imperative steps" = "imperative-steps.md";}
          {State = "state.md";}
          {"Common argument reference" = "module-reference.md";}
        ]
        ++ lib.optional (pages != {}) {
          Modules = lib.mapAttrsToList (moduleName: _: {${moduleName} = "modules/${moduleName}.md";}) pages;
        };
    };
  };
  # Keep Markdown sources separately buildable from the rendered local-file site.
  source = pkgs.linkFarm "${name}-documentation-source" ([
      {
        name = "docs/assets/nixos-logo.png";
        path = "${pkgs.nixos-icons}/share/icons/hicolor/32x32/apps/nix-snowflake.png";
      }
      {
        name = "zensical.toml";
        path = config;
      }
      {
        name = "docs/index.md";
        path = index;
      }
      {
        name = "docs/imperative-steps.md";
        path = combined;
      }
      {
        name = "docs/state.md";
        path = statePage;
      }
      {
        name = "docs/module-reference.md";
        path = reference;
      }
    ]
    ++ map (file: file // {name = "docs/${file.name}";}) moduleFiles);
  site =
    pkgs.runCommand "${name}-documentation-html" {
      nativeBuildInputs = [pkgs.zensical];
    } ''
      cp -rL ${source}/. .
      chmod -R u+w .
      zensical build --clean
      # The server error page uses root-relative assets and has no role in local navigation.
      rm site/404.html
      mkdir -p "$out/share/doc/${name}"
      cp -r site/. "$out/share/doc/${name}/"
    '';
  indexPath = "${site}/share/doc/${name}/index.html";
  openDocs = pkgs.writeShellApplication {
    name = "open-docs";
    text = ''
      exec ${lib.getExe pkgs.lynx} "$@" ${lib.escapeShellArg indexPath}
    '';
  };
  desktop = pkgs.makeDesktopItem {
    name = "host-documentation";
    desktopName = "${name} documentation";
    comment = "Open the documentation for this host";
    exec = "${lib.getExe' pkgs.xdg-utils "xdg-open"} ${indexPath}";
    icon = "help-browser";
    categories = ["Documentation" "Utility"];
    terminal = false;
  };
  package = pkgs.symlinkJoin {
    name = "${name}-documentation";
    paths = [site openDocs desktop];
    meta.mainProgram = "open-docs";
  };
in {
  inherit source site openDocs desktop package;
}
