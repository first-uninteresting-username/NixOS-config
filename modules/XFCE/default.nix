# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "XFCE";
  ids = ["XFCE" "terminal-emulator"];
  module = _: {
    nixos = {
      lib,
      pkgs,
      ...
    }: {
      services.xserver = {
        enable = true;
        excludePackages = [pkgs.xterm];
        desktopManager.xfce.enable = true;
      };

      # GNOME applications and Ghostty replace the bundled Xfce applications.
      environment.xfce.excludePackages = with pkgs; [
        mousepad
        parole
        ristretto
        xfce4-appfinder
        xfce4-taskmanager
        xfce4-terminal
      ];
      programs.thunar.enable = lib.mkForce false;

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
      ghostty = "${lib.getExe pkgs.ghostty} +new-window";
      launcher = "${lib.getExe config.programs.rofi.finalPackage} -show drun";
      workspaces = lib.range 1 4;
      wallpaper =
        if config ? stylix && config.stylix.enable
        then config.stylix.image
        else null;
      # xrdp names its outputs rdp0, rdp1 and so on.
      backdrops = lib.listToAttrs (lib.concatMap (monitor:
        lib.concatMap (workspace: let
          prefix = "backdrop/screen0/monitor${monitor}/workspace${toString workspace}";
        in [
          (lib.nameValuePair "${prefix}/last-image" "${wallpaper}")
          # 5 zooms the image to fill the monitor.
          (lib.nameValuePair "${prefix}/image-style" 5)
        ]) (lib.range 0 3)) ["rdp0" "rdp1"]);
    in {
      home.packages = with pkgs; [
        file-roller
        gnome-calculator
        gnome-text-editor
        loupe
        mission-center
        nautilus
        papers
        showtime
      ];

      programs.rofi.enable = true;

      stylix.targets.xfce.enable = true;

      xdg.configFile."xfce4/helpers.rc".text = ''
        TerminalEmulator=ghostty
        FileManager=nautilus
        WebBrowser=firefox
      '';
      xdg.dataFile."xfce4/helpers/ghostty.desktop".text = ''
        [Desktop Entry]
        NoDisplay=true
        Version=1.0
        Type=X-XFCE-Helper
        X-XFCE-Category=TerminalEmulator
        X-XFCE-Commands=${lib.getExe pkgs.ghostty}
        X-XFCE-CommandsWithParameter=${lib.getExe pkgs.ghostty} -e "%s"
        Icon=com.mitchellh.ghostty
        Name=Ghostty
      '';

      xdg.mimeApps = {
        enable = true;
        defaultApplications = {
          "inode/directory" = "org.gnome.Nautilus.desktop";
          "text/plain" = "org.gnome.TextEditor.desktop";
          "application/pdf" = "org.gnome.Papers.desktop";
          "image/png" = "org.gnome.Loupe.desktop";
          "image/jpeg" = "org.gnome.Loupe.desktop";
          "image/svg+xml" = "org.gnome.Loupe.desktop";
        };
      };

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

        xfwm4 = {
          "general/button_layout" = "O|HMC";
          "general/click_to_focus" = true;
          "general/workspace_count" = lib.length workspaces;
        };

        xfce4-desktop = lib.optionalAttrs (wallpaper != null) backdrops;

        keyboard-layout = {
          "Default/XkbDisable" = false;
          "Default/XkbLayout" = "pl";
          "Default/XkbVariant" = "";
          "Default/XkbOptions/Group" = "caps:swapescape";
        };

        # Bindings follow the GNOME hosts.
        xfce4-keyboard-shortcuts =
          {
            "commands/custom/<Super>Return" = ghostty;
            "commands/custom/<Super>e" = "${lib.getExe pkgs.nautilus} --new-window";
            "commands/custom/<Super>space" = launcher;
            "commands/custom/<Super>r" = launcher;
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
