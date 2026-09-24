# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{self, ...}: {
  flake = {
    nixosModules.GNOME = {
      lib,
      config,
      pkgs,
      ...
    }: let
      cfg = config.custom.DE;
    in {
      imports = [
        self.nixosModules.wayland
      ];
      config = lib.mkIf cfg.enable {
        preservation.preserveAt = lib.mkIf config.custom.preservation.enable {
          "/persist" = {
            directories = [
              "/var/lib/gdm"
            ];
            users.${config.custom.user.name} = {
              directories = [
                ".local/share/keyrings"
                ".local/share/nautilus"
                ".config/goa-1.0"
                ".cache/tracker3"
              ];
              files = [
                ".local/share/recently-used.xbel"
                ".config/hexecute/gestures.json"
              ];
            };
          };
        };

        programs = {
          ssh.startAgent = lib.mkForce false;
          dconf.enable = true;
          nautilus-open-any-terminal = {
            enable = true;
            terminal = "ptyxis";
          };
        };

        services = {
          xserver = {
            enable = true;
            excludePackages = [pkgs.xterm];
          };
          desktopManager.gnome.enable = true;
          displayManager.gdm.enable = true;
          gnome = {
            sushi.enable = true;
            gnome-software.enable = false;
            gnome-initial-setup.enable = false;
            games.enable = false;
            core-developer-tools.enable = false;
          };
        };

        stylix.targets = {
          gnome.enable = true;
        };

        environment = {
          gnome.excludePackages = with pkgs; [
            gnome-tour
            orca
            epiphany
            gnome-system-monitor
            gnome-tecla
            gnome-software
            gnome-console
            yelp
          ];
        };

        xdg.portal = {
          enable = true;
          extraPortals = [
            pkgs.xdg-desktop-portal-gnome
          ];
        };

        home-manager.users.${config.custom.user.name} = {
          pkgs,
          lib,
          ...
        }: {
          home = {
            packages = with pkgs; [
              mission-center
              self.inputs.hexecute-gnome.packages.${pkgs.stdenv.hostPlatform.system}.default
            ];

            # Hexecute throws errors without it
            activation.seedHexecuteGestures = lib.hm.dag.entryAfter ["writeBoundary"] ''
              gesturesFile="$HOME/.config/hexecute/gestures.json"; mkdir -p "$(dirname "$gesturesFile")"
              if [ ! -s "$gesturesFile" ]; then
                printf '[]\n' > "$gesturesFile"
              fi
            '';
          };

          stylix.targets = {
            gnome.colors.enable = false;
            gtk.colors.enable = false;
          };

          programs = {
            gnome-shell = {
              enable = true;

              extensions = map (pkg: {package = pkg;}) (
                with pkgs.gnomeExtensions; [
                  appindicator
                  blur-my-shell
                  clipboard-indicator
                  just-perfection
                  caffeine
                  dash-to-dock
                  gsconnect
                  launch-new-instance
                  logo-menu
                  vitals
                  hide-cursor
                  tiling-shell
                ]
              );
            };
          };

          dconf = {
            enable = true;
            settings = {
              "org/gnome/desktop/input-sources" = {
                current = 0;
                sources = [
                  (lib.hm.gvariant.mkTuple [
                    "xkb"
                    "pl"
                  ])
                ];
                xkb-options = ["caps:swapescape"];
              };
              "org/gnome/desktop/interface" = {
                clock-format = "24h";
                color-scheme = "prefer-dark";
                cursor-theme = "Bibata-Modern-Ice";
                enable-animations = true;
                enable-hot-corners = true;
                gtk-enable-primary-paste = false;
                gtk-key-theme = "Default";
                accent-color = "slate";
                show-battery-percentage = true;
              };
              "org/gnome/desktop/peripherals/keyboard" = {
                numlock-state = false;
              };
              "org/gnome/desktop/peripherals/mouse" = {
                natural-scroll = true;
                speed = 0.0;
              };
              "org/gnome/desktop/peripherals/touchpad" = {
                two-finger-scrolling-enabled = true;
                tap-to-click = true;
              };
              "org/gnome/desktop/privacy" = {
                report-technical-problems = true;
              };
              "org/gnome/desktop/wm/preferences" = {
                button-layout = "appmenu:minimize,maximize,close";
                resize-with-right-button = true;
                focus-mode = "click";
                auto-raise = false;
              };
              "org/gnome/desktop/wm/keybindings" = {
                switch-to-workspace-1 = ["<Super>1"];
                switch-to-workspace-2 = ["<Super>2"];
                switch-to-workspace-3 = ["<Super>3"];
                switch-to-workspace-4 = ["<Super>4"];
                move-to-workspace-1 = ["<Super><Shift>1"];
                move-to-workspace-2 = ["<Super><Shift>2"];
                move-to-workspace-3 = ["<Super><Shift>3"];
                move-to-workspace-4 = ["<Super><Shift>4"];
                show-desktop = ["<Super>d"];
                close = ["<Super>q"];
                switch-input-source = [];
                switch-input-source-backward = [];
                activate-window-menu = ["<Alt><Super>space"];
                minimize = ["<Super>g"];
                maximize = ["<Super>f"];
                move-to-workspace-left = [];
                move-to-workspace-right = [];
                move-to-monitor-left = [];
                move-to-monitor-right = [];
                move-to-monitor-up = [];
                move-to-monitor-down = [];
              };
              "org/gnome/login-screen" = {
                enable-fingerprint-authentication = true;
                enable-smartcard-authentication = false;
              };
              "org/gnome/mutter" = {
                edge-tiling = false;
                overlay-key = "Super_L";
                experimental-features = ["scale-monitor-framebuffer"];
              };
              "org/gnome/mutter/keybindings" = {
                toggle-tiled-left = [];
                toggle-tiled-right = [];
              };
              "org/gnome/mutter/wayland/keybindings" = {
                restore-shortcuts = [];
              };
              "org/gnome/nautilus/preferences" = {
                default-folder-viewer = "icon-view";
                migrated-gtk-settings = true;
                search-filter-time-type = "last_modified";
                show-create-link = true;
              };
              "org/gnome/shell" = {
                favorite-apps = [
                  "firefox.desktop"
                  "org.gnome.Ptyxis.desktop"
                  "org.gnome.Nautilus.desktop"
                  "dev.zed.Zed.desktop"
                ];
              };
              "org/gnome/shell/extensions/Logo-menu" = {
                hide-forcequit = true;
                menu-button-icon-image = 23;
                menu-button-icon-size = 20;
                menu-button-system-monitor = "${pkgs.mission-center}/bin/missioncenter";
                menu-button-terminal = "${pkgs.ptyxis}/bin/ptyxis --new-window";
                show-activities-button = true;
                show-gamemode = true;
                show-lockscreen = true;
                show-power-option = false;
                show-power-options = true;
                symbolic-icon = true;
                use-custom-icon = false;
                hide-softwarecentre = false;
              };
              "org/gnome/shell/extensions/blur-my-shell/appfolder" = {
                brightness = 0.6;
                sigma = 30;
              };
              "org/gnome/shell/extensions/blur-my-shell/dash-to-dock" = {
                blur = true;
                brightness = 0.6;
                sigma = 30;
                static-blur = true;
                style-dash-to-dock = 0;
              };
              "org/gnome/shell/extensions/blur-my-shell/panel" = {
                brightness = 0.6;
                sigma = 30;
              };
              "org/gnome/shell/extensions/blur-my-shell/window-list" = {
                brightness = 0.6;
                sigma = 30;
              };
              "org/gnome/shell/extensions/caffeine" = {
                indicator-position-max = 2;
              };
              "org/gnome/shell/extensions/clipboard-indicator" = {
                history-size = 200;
                toggle-menu = ["<Super>b"];
              };
              "org/gnome/shell/extensions/vitals" = {
                position-in-panel = 0;
              };
              "org/gnome/shell/extensions/dash-to-dock" = {
                background-opacity = 0.8;
                click-action = "launch";
                custom-background-color = false;
                dash-max-icon-size = 48;
                dock-fixed = false;
                dock-position = "BOTTOM";
                height-fraction = 0.9;
                hot-keys = false;
                intellihide-mode = "ALL_WINDOWS";
                middle-click-action = "launch";
                preferred-monitor = -2;
                preferred-monitor-by-connector = "DP-2";
                scroll-action = "switch-workspace";
                shift-click-action = "minimize";
                shift-middle-click-action = "launch";
              };
              "org/gnome/shell/extensions/gsconnect" = {
                devices = [];
                enabled = true;
                missing-openssl = false;
              };
              "org/gnome/shell/extensions/tilingshell" = {
                outer-gaps = lib.hm.gvariant.mkUint32 0;
              };
              "org/gnome/shell/weather" = {
                automatic-location = true;
                locations = [];
              };
              "org/gnome/shell/world-clocks" = {
                locations = [];
              };
              "org/gnome/system/location" = {
                enabled = true;
              };
              "org/gnome/tweaks" = {
                show-extensions-notice = false;
              };
              "org/gtk/gtk4/settings/file-chooser" = {
                show-hidden = true;
                sort-directories-first = true;
              };
              "org/gtk/settings/file-chooser" = {
                clock-format = "24h";
                date-format = "regular";
                location-mode = "path-bar";
                show-hidden = true;
                show-size-column = true;
                show-type-column = true;
                sort-column = "name";
                sort-directories-first = true;
                sort-order = "ascending";
                type-format = "category";
              };
              "org/gnome/shell/keybindings" = {
                screenshot = [];
                show-screenshot-ui = [];
              };
              "org/gnome/settings-daemon/plugins/media-keys" = {
                screensaver = ["<Super>p"];
              };
              "org/gnome/shell/extensions/just-perfection" = {
                support-notifier-type = 0;
              };
              "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/terminal" = {
                binding = "<Super>Return";
                command = "${pkgs.ptyxis}/bin/ptyxis --new-window";
                name = "Terminal";
              };
              "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/files" = {
                binding = "<Super>e";
                command = "xdg-open .";
                name = "File Manager";
              };
              "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/gradia" = {
                binding = "<Shift>Print";
                command = "${pkgs.gradia}/bin/gradia  --screenshot=INTERACTIVE";
                name = "Screenshot";
              };
              "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/hexecute" = {
                binding = "<Super>Space";
                command = "${self.packages.${pkgs.stdenv.hostPlatform.system}.hexecute-gnome}/bin/hexecute";
                name = "Hexecute";
              };
              "org/gnome/settings-daemon/plugins/media-keys" = {
                custom-keybindings = [
                  "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/terminal/"
                  "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/files/"
                  "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/gradia/"
                  "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/hexecute/"
                ];
              };
            };
          };
        };
      };
    };
  };
}
