# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "XFCE";
  ids = ["XFCE"];
  module = _: {
    nixos = {pkgs, ...}: {
      services.xserver = {
        enable = true;
        excludePackages = [pkgs.xterm];
        desktopManager.xfce.enable = true;
      };

      programs.dconf.enable = true;

      # The ssh module runs the OpenSSH agent; XFCE would add a second one.
      services.gnome.gcr-ssh-agent.enable = false;
    };
    home = {
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
      workspaces = lib.range 1 4;
      # xrdp names its outputs rdp0, rdp1 and so on.
      backdrops = lib.listToAttrs (lib.concatMap (monitor:
        lib.concatMap (workspace: let
          prefix = "backdrop/screen0/monitor${monitor}/workspace${toString workspace}";
        in [
          (lib.nameValuePair "${prefix}/last-image" "${stylix.image}")
          # 5 zooms the image to fill the monitor.
          (lib.nameValuePair "${prefix}/image-style" 5)
        ]) (lib.range 0 3)) ["rdp0" "rdp1"]);
      # The dock matches the GNOME favorites: browser, terminal and file manager.
      browserEntry =
        if config.programs.firefox.enable
        then "${config.programs.firefox.finalPackage}/share/applications/firefox.desktop"
        else
          pkgs.writeText "web-browser.desktop" ''
            [Desktop Entry]
            Type=Application
            Name=Web Browser
            Exec=exo-open --launch WebBrowser %u
            Icon=org.xfce.webbrowser
          '';
      dockLaunchers = [
        {
          id = 19;
          name = "browser.desktop";
          source = browserEntry;
        }
        {
          id = 20;
          name = "terminal.desktop";
          source = "${pkgs.xfce4-terminal}/share/applications/xfce4-terminal.desktop";
        }
        {
          id = 21;
          name = "files.desktop";
          source = "${pkgs.thunar}/share/applications/thunar.desktop";
        }
      ];
    in {
      imports = [./_rofi.nix];

      xdg.configFile = lib.listToAttrs (map (launcher:
        lib.nameValuePair "xfce4/panel/launcher-${toString launcher.id}/${launcher.name}" {
          inherit (launcher) source;
        })
      dockLaunchers);

      stylix.targets.xfce.enable = true;

      xfconf.settings = {
        # Xfce's settings daemon overrides GTK settings files, so mirror the Stylix choices.
        xsettings =
          {"Gtk/DecorationLayout" = "menu:minimize,maximize,close";}
          // lib.optionalAttrs (config.gtk.theme != null) {
            "Net/ThemeName" = config.gtk.theme.name;
          }
          // lib.optionalAttrs (config.gtk.iconTheme != null) {
            "Net/IconThemeName" = config.gtk.iconTheme.name;
          }
          // lib.optionalAttrs (config.home.pointerCursor != null) {
            "Gtk/CursorThemeName" = config.home.pointerCursor.name;
            "Gtk/CursorThemeSize" = config.home.pointerCursor.size;
          };

        xfce4-panel =
          {
            "panels/panel-2/plugin-ids" = map (launcher: launcher.id) dockLaunchers;
          }
          // lib.listToAttrs (lib.concatMap (launcher: let
              plugin = "plugins/plugin-${toString launcher.id}";
            in [
              (lib.nameValuePair plugin "launcher")
              (lib.nameValuePair "${plugin}/items" [launcher.name])
            ])
            dockLaunchers);

        xfwm4 = {
          "general/button_layout" = "O|HMC";
          "general/click_to_focus" = true;
          "general/workspace_count" = lib.length workspaces;
        };

        xfce4-desktop =
          # 0 hides desktop icons.
          {"desktop-icons/style" = 0;}
          // lib.optionalAttrs (stylix != null && stylix.image != null) backdrops;

        # Stylix has no xfce4-terminal target; this follows its base16 terminal mapping.
        xfce4-terminal = lib.optionalAttrs (stylix != null) {
          color-use-theme = false;
          color-foreground = colors.base05;
          color-background = colors.base00;
          color-cursor-use-default = false;
          color-cursor = colors.base05;
          color-cursor-foreground = colors.base00;
          color-bold-use-default = true;
          color-palette = lib.concatStringsSep ";" (map (name: colors.${name}) [
            "base00"
            "base08"
            "base0B"
            "base0A"
            "base0D"
            "base0E"
            "base0C"
            "base05"
            "base03"
            "base08"
            "base0B"
            "base0A"
            "base0D"
            "base0E"
            "base0C"
            "base07"
          ]);
          font-use-system = false;
          font-name = "${stylix.fonts.monospace.name} ${toString stylix.fonts.sizes.terminal}";
          misc-menubar-default = false;
        };

        keyboard-layout = {
          "Default/XkbDisable" = false;
          "Default/XkbLayout" = "pl";
          "Default/XkbVariant" = "";
          "Default/XkbOptions/Group" = "caps:swapescape";
        };

        # Bindings follow the GNOME hosts with Ctrl+Shift in place of Super, and Alt in place
        # of the extra Shift. Earlier Super and Ctrl variants are reset so they do not linger.
        xfce4-keyboard-shortcuts = let
          bindings = mod: extra:
            {
              "commands/custom/${mod}Return" = "xfce4-terminal";
              "commands/custom/${mod}e" = "thunar";
              "commands/custom/${mod}space" = "rofi-show drun";
              "commands/custom/${mod}period" = "rofi-show emoji";
              "commands/custom/${extra}v" = "rofi-show clipboard";
              "xfwm4/custom/${mod}Tab" = "cycle_windows_key";
              "xfwm4/custom/${extra}Tab" = "cycle_reverse_windows_key";
              "xfwm4/custom/${mod}q" = "close_window_key";
              "xfwm4/custom/${mod}d" = "show_desktop_key";
              "xfwm4/custom/${mod}f" = "maximize_window_key";
              "xfwm4/custom/${mod}g" = "hide_window_key";
              "xfwm4/custom/<Alt>${mod}space" = "popup_menu_key";
            }
            // lib.listToAttrs (lib.concatMap (n: [
                (lib.nameValuePair "xfwm4/custom/${mod}${toString n}" "workspace_${toString n}_key")
                (lib.nameValuePair "xfwm4/custom/${extra}${toString n}"
                  "move_window_workspace_${toString n}_key")
              ])
              workspaces);
        in
          lib.mapAttrs (_: _: null) (bindings "<Super>" "<Shift><Super>" // bindings "<Primary>" "<Shift><Primary>")
          // bindings "<Primary><Shift>" "<Primary><Shift><Alt>";
      };
    };
  };
}
