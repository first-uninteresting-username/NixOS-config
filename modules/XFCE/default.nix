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

      environment.systemPackages = [pkgs.xfce4-docklike-plugin];

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
      uiFont = "Inter";
      iconTheme = "Papirus-Dark";
      rofi = lib.getExe config.programs.rofi.finalPackage;
      # xrdp names its outputs rdp0, rdp1 and so on; QEMU previews use Virtual-1.
      backdrops = lib.listToAttrs (lib.concatMap (monitor:
        lib.concatMap (workspace: let
          prefix = "backdrop/screen0/monitor${monitor}/workspace${toString workspace}";
        in [
          (lib.nameValuePair "${prefix}/last-image" "${stylix.image}")
          # 5 zooms the image to fill the monitor.
          (lib.nameValuePair "${prefix}/image-style" 5)
        ]) (lib.range 0 3)) ["rdp0" "rdp1" "Virtual-1"]);
      # The dock pins the GNOME favorites: browser, terminal and file manager.
      pinnedApps = [
        (
          if config.programs.firefox.enable
          then "firefox"
          else "xfce4-web-browser"
        )
        "xfce4-terminal"
        "thunar"
      ];
      xfwm4Theme = import ./_xfwm4-theme.nix {inherit lib pkgs colors;};
      rgba = hex: alpha:
        map (i: (lib.fromHexString (builtins.substring i 2 hex)) / 255.0) [1 3 5] ++ [alpha];
      uint = value: {
        type = "uint";
        inherit value;
      };
      # Panel plugins: the top bar holds 30 to 37 and the dock holds 19.
      launcher = name: desktop: {
        inherit name;
        source = pkgs.writeText name (lib.generators.toINI {} {"Desktop Entry" = desktop // {Type = "Application";};});
      };
      appsLauncher = launcher "apps.desktop" {
        Name = "Applications";
        Exec = "${rofi} -show drun";
        Icon = "view-app-grid-symbolic";
      };
      powerLauncher = launcher "power.desktop" {
        Name = "Power";
        Exec = "xfce4-session-logout";
        Icon = "system-shutdown-symbolic";
      };
      topBar = [
        {
          id = 30;
          type = "launcher";
          settings.items = [appsLauncher.name];
          desktop = appsLauncher;
        }
        {
          id = 31;
          type = "pager";
          settings = {
            # Numbered buttons instead of window miniatures.
            miniature-view = false;
            rows = uint 1;
          };
        }
        {
          id = 32;
          type = "separator";
          settings = {
            expand = true;
            style = uint 0;
          };
        }
        {
          id = 33;
          type = "clock";
          settings = {
            mode = uint 2;
            # 3 shows only the time line, using the format below.
            digital-layout = uint 3;
            digital-time-format = "%a %-d %b  %H:%M";
          };
        }
        {
          id = 34;
          type = "separator";
          settings = {
            expand = true;
            style = uint 0;
          };
        }
        {
          id = 35;
          type = "systray";
          settings = {
            square-icons = true;
            icon-size = 16;
            # The server's network needs no applet.
            hidden-legacy-items = ["networkmanager applet"];
          };
        }
        {
          id = 36;
          type = "pulseaudio";
          settings = {};
        }
        {
          id = 37;
          type = "notification-plugin";
          settings = {};
        }
        {
          id = 38;
          type = "launcher";
          settings.items = [powerLauncher.name];
          desktop = powerLauncher;
        }
      ];
      dock = {
        id = 19;
        type = "docklike";
        settings = {};
      };
      pluginSettings = plugin:
        [(lib.nameValuePair "plugins/plugin-${toString plugin.id}" plugin.type)]
        ++ lib.mapAttrsToList (key:
          lib.nameValuePair "plugins/plugin-${toString plugin.id}/${key}")
        plugin.settings;
    in {
      # Docklike reads this file until the user changes a dock setting.
      xdg.configFile."xfce4/panel/docklike.rc".text = lib.generators.toINI {} {
        user = {
          pinned = lib.concatStringsSep ";" pinnedApps + ";";
          showPreviews = false;
          # Super+number switches workspaces instead.
          keyComboActive = false;
        };
      };

      xdg.configFile."xfce4/panel/launcher-30/${appsLauncher.name}".source = appsLauncher.source;
      xdg.configFile."xfce4/panel/launcher-38/${powerLauncher.name}".source = powerLauncher.source;

      xdg.dataFile."themes/Stylix/xfwm4".source = "${xfwm4Theme}/xfwm4";

      home.packages = [pkgs.inter pkgs.papirus-icon-theme];

      # Rofi renders on the CPU, unlike most themed launchers.
      programs.rofi = {
        enable = true;
        settings = {
          modes = "drun,run,window";
          show-icons = true;
          icon-theme = iconTheme;
          display-drun = "";
          display-run = "";
          display-window = "";
          drun-display-format = "{name}";
        };
        theme = import ./_rofi-theme.nix {inherit config colors uiFont;};
      };

      stylix.targets.xfce.enable = true;
      stylix.targets.rofi.enable = false;
      stylix.targets.gtk.extraCss = import ./_gtk.css.nix {inherit colors;};

      xfconf.settings = {
        # Xfce's settings daemon overrides GTK settings files, so mirror the Stylix choices.
        xsettings =
          {"Gtk/DecorationLayout" = "menu:minimize,maximize,close";}
          // lib.optionalAttrs (config.gtk.theme != null) {
            "Net/ThemeName" = config.gtk.theme.name;
          }
          // {
            # Papirus covers the Xfce applications that Stylix's icon theme lacks.
            "Net/IconThemeName" = iconTheme;
            "Gtk/FontName" = lib.mkForce "${uiFont} 10";
            "Gtk/ButtonImages" = false;
            "Gtk/MenuImages" = false;
            "Xft/Antialias" = 1;
            "Xft/Hinting" = 1;
            "Xft/HintStyle" = "hintslight";
            "Xft/RGBA" = "rgb";
          }
          // lib.optionalAttrs (config.home.pointerCursor != null) {
            "Gtk/CursorThemeName" = config.home.pointerCursor.name;
            "Gtk/CursorThemeSize" = config.home.pointerCursor.size;
          };

        xfce4-panel =
          {
            configver = 2;
            panels = [1 2];
            "panels/dark-mode" = true;

            "panels/panel-1/position" = "p=6;x=0;y=0";
            "panels/panel-1/position-locked" = true;
            "panels/panel-1/length" = uint 100;
            "panels/panel-1/size" = uint 30;
            "panels/panel-1/icon-size" = uint 16;
            "panels/panel-1/background-style" = uint 1;
            "panels/panel-1/background-rgba" = rgba colors.base00 1.0;
            "panels/panel-1/plugin-ids" = map (plugin: plugin.id) topBar;

            "panels/panel-2/position" = "p=10;x=0;y=0";
            "panels/panel-2/position-locked" = true;
            "panels/panel-2/length" = uint 1;
            "panels/panel-2/length-adjust" = true;
            "panels/panel-2/size" = uint 52;
            # 1 hides the dock when a window overlaps it.
            "panels/panel-2/autohide-behavior" = uint 1;
            "panels/panel-2/background-style" = uint 1;
            "panels/panel-2/background-rgba" = rgba colors.base00 0.0;
            "panels/panel-2/plugin-ids" = [dock.id];
          }
          // lib.listToAttrs (lib.concatMap pluginSettings (topBar ++ [dock]));

        xfwm4 = {
          "general/theme" = "Stylix";
          "general/title_font" = lib.mkForce "${uiFont} Semi-Bold 10";
          # Dragging a window to an edge tiles it; super-drag moves it from anywhere.
          "general/tile_on_move" = true;
          "general/easy_click" = "Super";
          "general/snap_to_border" = true;
          "general/snap_to_windows" = true;
          "general/wrap_windows" = false;
          "general/placement_ratio" = 100;
          "general/placement_mode" = "center";
          "general/borderless_maximize" = true;
          "general/titleless_maximize" = false;
          "general/cycle_preview" = false;
          "general/cycle_tabwin_mode" = 1;
          "general/button_layout" = "|HMC";
          "general/title_alignment" = "center";
          # XRender compositing runs on the CPU and draws the rounded corners and shadows.
          "general/use_compositing" = true;
          "general/vblank_mode" = "off";
          "general/show_frame_shadow" = true;
          "general/show_popup_shadow" = true;
          "general/show_dock_shadow" = false;
          "general/zoom_desktop" = false;
          "general/click_to_focus" = true;
          "general/workspace_count" = lib.length workspaces;
          "general/workspace_names" = map toString workspaces;
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
          misc-toolbar-default = false;
          scrolling-bar = "TERMINAL_SCROLLBAR_NONE";
        };

        thunar = {
          last-menubar-visible = false;
          last-statusbar-visible = false;
          last-location-bar = "ThunarLocationButtons";
          last-view = "ThunarIconView";
          last-icon-view-zoom-level = "THUNAR_ZOOM_LEVEL_75_PERCENT";
          last-separator-position = 180;
          misc-symbolic-icons-in-toolbar = true;
          misc-full-path-in-tab-title = false;
          misc-show-delete-action = false;
        };

        keyboard-layout = {
          "Default/XkbDisable" = false;
          "Default/XkbLayout" = "pl";
          "Default/XkbVariant" = "";
          "Default/XkbOptions/Group" = "caps:swapescape";
        };

        # Bindings follow the GNOME hosts.
        xfce4-keyboard-shortcuts =
          {
            # Without the override flags, xfsettingsd replaces these with Xfce's defaults.
            "commands/custom/override" = true;
            "xfwm4/custom/override" = true;
            "commands/custom/Print" = "xfce4-screenshooter";
            "commands/custom/<Primary><Alt>Delete" = "xfce4-session-logout";
            "commands/custom/<Primary><Alt>l" = "xflock4";
            "xfwm4/custom/<Alt>Tab" = "cycle_windows_key";
            "xfwm4/custom/<Alt><Shift>Tab" = "cycle_reverse_windows_key";
            "xfwm4/custom/<Alt>F4" = "close_window_key";
            "xfwm4/custom/<Alt>F7" = "move_window_key";
            "xfwm4/custom/<Alt>F8" = "resize_window_key";
            "xfwm4/custom/<Alt>F11" = "fullscreen_key";
            # Move, resize and the window switcher read these while active.
            "xfwm4/custom/Escape" = "cancel_key";
            "xfwm4/custom/Up" = "up_key";
            "xfwm4/custom/Down" = "down_key";
            "xfwm4/custom/Left" = "left_key";
            "xfwm4/custom/Right" = "right_key";
            "commands/custom/<Super>Return" = "xfce4-terminal";
            "commands/custom/<Super>e" = "thunar";
            "commands/custom/<Super>space" = "${rofi} -show drun";
            "commands/custom/<Super>r" = "${rofi} -show run";
            "xfwm4/custom/<Super>Left" = "tile_left_key";
            "xfwm4/custom/<Super>Right" = "tile_right_key";
            "xfwm4/custom/<Super>Up" = "maximize_window_key";
            "xfwm4/custom/<Super>Down" = "hide_window_key";
            "xfwm4/custom/<Super>Tab" = "cycle_windows_key";
            "xfwm4/custom/<Shift><Super>Tab" = "cycle_reverse_windows_key";
            "xfwm4/custom/<Super>q" = "close_window_key";
            "xfwm4/custom/<Super>d" = "show_desktop_key";
            "xfwm4/custom/<Super>f" = "maximize_window_key";
            "xfwm4/custom/<Super>g" = "hide_window_key";
            "xfwm4/custom/<Alt><Super>space" = "popup_menu_key";
          }
          // lib.listToAttrs (lib.concatMap (n: [
              (lib.nameValuePair "xfwm4/custom/<Super>${toString n}" "workspace_${toString n}_key")
              (lib.nameValuePair "xfwm4/custom/<Shift><Super>${toString n}"
                "move_window_workspace_${toString n}_key")
            ])
            workspaces);
      };
    };
  };
}
