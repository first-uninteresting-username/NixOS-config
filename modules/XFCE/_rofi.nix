# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
# Rofi launcher for XFCE: a Stylix-coloured popup with mode tabs for apps, windows, files,
# a calculator, emoji, clipboard history and session actions.
{
  config,
  lib,
  pkgs,
  ...
}: let
  stylix =
    if config ? stylix && config.stylix.enable
    then config.stylix
    else null;
  colors = config.lib.stylix.colors.withHashtag;
  inherit (config.lib.formats.rasi) mkLiteral;
  rofi = lib.getExe config.programs.rofi.finalPackage;
  xclip = lib.getExe pkgs.xclip;
  greenclip = lib.getExe pkgs.haskellPackages.greenclip;

  # Script mode: list session actions, then ask for confirmation before running one.
  session = pkgs.writeShellScript "rofi-session" ''
    case "''${1-}" in
      "")
        printf '%s\n' "Log out" "Reboot"
        ;;
      "Log out" | "Reboot")
        printf '\0prompt\x1f%s?\n' "$1"
        printf '%s\n' "Yes, $1" "Cancel"
        ;;
      "Yes, Log out")
        exec xfce4-session-logout --logout --fast >/dev/null 2>&1
        ;;
      "Yes, Reboot")
        exec xfce4-session-logout --reboot --fast >/dev/null 2>&1
        ;;
    esac
  '';

  modes = [
    {
      name = "drun";
      label = "󰀻 Apps";
    }
    {
      name = "window";
      label = "󰖲 Windows";
    }
    {
      name = "filebrowser";
      label = "󰉋 Files";
    }
    {
      name = "calc";
      label = "󰃬 Calc";
    }
    {
      name = "emoji";
      label = "󰇵 Emoji";
    }
    {
      name = "clipboard";
      label = "󰅍 Clipboard";
      script = "${greenclip} print";
    }
    {
      name = "session";
      label = "󰐥 Session";
      script = session;
    }
  ];
in {
  programs.rofi = {
    enable = true;
    plugins = [pkgs.rofi-calc pkgs.rofi-emoji];
    settings =
      {
        terminal = "xfce4-terminal";
        modes = map (mode:
          if mode ? script
          then "${mode.name}:${mode.script}"
          else mode.name)
        modes;
        show-icons = true;
        matching = "fuzzy";
        sort = true;
        sorting-method = "fzf";
        case-sensitive = false;
        drun-display-format = "{name}";
        window-format = "{c}  {t}";
        # Tab switches modes like the tab bar suggests; arrows move through results.
        kb-element-next = "";
        kb-element-prev = "";
        kb-mode-next = "Tab,Control+Tab,Shift+Right";
        kb-mode-previous = "ISO_Left_Tab,Control+ISO_Left_Tab,Shift+Left";
        kb-row-up = "Up,Control+p,Control+k";
        kb-row-down = "Down,Control+n,Control+j";
        kb-remove-to-eol = "";
        kb-accept-entry = "Return,KP_Enter,Control+m";
      }
      // lib.optionalAttrs (stylix != null) {
        font = "${stylix.fonts.sansSerif.name} 12";
      }
      // lib.optionalAttrs (config.gtk.iconTheme != null) {
        icon-theme = config.gtk.iconTheme.name;
      }
      // lib.listToAttrs (map (mode: lib.nameValuePair mode.name {display-name = mode.label;}) modes);

    theme = lib.mkIf (stylix != null) {
      "*" = {
        bg = mkLiteral colors.base00;
        bg-alt = mkLiteral colors.base01;
        sel = mkLiteral colors.base02;
        fg = mkLiteral colors.base05;
        fg-muted = mkLiteral colors.base04;
        accent = mkLiteral colors.base0D;
        urgent = mkLiteral colors.base08;

        background-color = mkLiteral "transparent";
        text-color = mkLiteral "@fg";
        margin = 0;
        padding = 0;
        spacing = 0;
      };
      window = {
        location = mkLiteral "center";
        width = mkLiteral "820px";
        background-color = mkLiteral "@bg";
        border = mkLiteral "2px";
        border-color = mkLiteral "@accent";
        border-radius = mkLiteral "14px";
      };
      mainbox = {
        padding = mkLiteral "14px";
        spacing = mkLiteral "12px";
        children = map mkLiteral ["inputbar" "message" "listview" "mode-switcher"];
      };
      inputbar = {
        padding = mkLiteral "10px 14px";
        spacing = mkLiteral "10px";
        background-color = mkLiteral "@bg-alt";
        border-radius = mkLiteral "10px";
        children = map mkLiteral ["prompt" "entry" "num-filtered-rows" "textbox-num-sep" "num-rows"];
      };
      prompt.text-color = mkLiteral "@accent";
      entry = {
        placeholder = "Search…";
        placeholder-color = mkLiteral "@fg-muted";
        cursor = mkLiteral "text";
      };
      "num-filtered-rows, textbox-num-sep, num-rows" = {
        expand = false;
        text-color = mkLiteral "@fg-muted";
      };
      textbox-num-sep.str = "/";
      message = {
        padding = mkLiteral "8px 12px";
        background-color = mkLiteral "@bg-alt";
        border-radius = mkLiteral "10px";
      };
      listview = {
        lines = 8;
        columns = 1;
        fixed-height = true;
        dynamic = true;
        scrollbar = false;
        spacing = mkLiteral "4px";
      };
      element = {
        padding = mkLiteral "8px 12px";
        spacing = mkLiteral "12px";
        border-radius = mkLiteral "10px";
        cursor = mkLiteral "pointer";
      };
      "element normal.active".text-color = mkLiteral "@accent";
      "element normal.urgent".text-color = mkLiteral "@urgent";
      "element selected.normal".background-color = mkLiteral "@sel";
      "element selected.active" = {
        background-color = mkLiteral "@accent";
        text-color = mkLiteral "@bg";
      };
      "element selected.urgent" = {
        background-color = mkLiteral "@urgent";
        text-color = mkLiteral "@bg";
      };
      "element-icon" = {
        size = mkLiteral "1.6em";
        vertical-align = mkLiteral "0.5";
      };
      "element-text" = {
        text-color = mkLiteral "inherit";
        vertical-align = mkLiteral "0.5";
        highlight = mkLiteral "bold ${colors.base0A}";
      };
      mode-switcher.spacing = mkLiteral "8px";
      button = {
        padding = mkLiteral "8px 6px";
        background-color = mkLiteral "@bg-alt";
        text-color = mkLiteral "@fg-muted";
        border-radius = mkLiteral "10px";
        cursor = mkLiteral "pointer";
      };
      "button selected" = {
        background-color = mkLiteral "@accent";
        text-color = mkLiteral "@bg";
      };
    };
  };

  # The theme above replaces Stylix's rofi theme.
  stylix.targets.rofi.enable = false;

  # Greenclip records clipboard history for the clipboard mode. The xrdp session does
  # not reach graphical-session.target, so it starts through XDG autostart.
  xdg.configFile."autostart/greenclip.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Greenclip
    Exec=${greenclip} daemon
    NoDisplay=true
  '';

  # Opens rofi on one mode: rofi-show drun, rofi-show emoji and so on. rofi-calc reads
  # its options only from the command line; Enter copies the result.
  home.packages = [
    (pkgs.writeShellScriptBin "rofi-show" ''
      exec ${rofi} -show "''${1:-drun}" \
        -calc-command "printf %s '{result}' | ${xclip} -selection clipboard"
    '')
  ];
}
