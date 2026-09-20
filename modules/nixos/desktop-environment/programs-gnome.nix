# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  flake = {
    nixosModules.DE-programs-gnome = {
      lib,
      config,
      ...
    }: let
      cfg = config.custom.DE.programs;
      ptyxisUUID = "00000000-0000-0000-0000-000000000000";
    in {
      config = lib.mkIf config.custom.DE.enable {
        home-manager.users.${config.custom.user.name} = {pkgs, ...}:
          lib.mkMerge [
            (lib.mkIf (cfg.fileManager == "gnome") {
              home.packages = [pkgs.nautilus];
              # You can add arbitrary settings here! Example:
              # dconf.settings."org/gnome/nautilus/preferences".default-folder-viewer = "icon-view";
            })

            (lib.mkIf (cfg.documentViewer == "gnome") {
              home.packages = [pkgs.papers];
            })

            (lib.mkIf (cfg.archiveTool == "gnome") {
              home.packages = [pkgs.file-roller];
            })

            (lib.mkIf (cfg.screenshotUtility == "gnome") {
              home.packages = [pkgs.kooha pkgs.gradia];
            })

            (lib.mkIf (cfg.systemMonitor == "gnome") {
              home.packages = [pkgs.mission-center];
            })

            (lib.mkIf (cfg.textEditor == "gnome") {
              home.packages = [pkgs.gnome-text-editor];
            })

            (lib.mkIf (cfg.imageViewer == "gnome") {
              home.packages = [pkgs.loupe];
            })

            (lib.mkIf (cfg.paintingApp == "gnome") {
              home.packages = [pkgs.pinta];
            })

            (lib.mkIf (cfg.calculator == "gnome") {
              home.packages = [pkgs.gnome-calculator];
            })

            (lib.mkIf (cfg.characterSelector == "gnome") {
              home.packages = [pkgs.gnome-characters];
            })

            (lib.mkIf (cfg.isoWriter == "gnome") {
              home.packages = [pkgs.impression];
            })

            (lib.mkIf (cfg.diskUsageViewer == "gnome") {
              home.packages = [pkgs.baobab];
            })

            (lib.mkIf (cfg.musicPlayer == "gnome") {
              home.packages = [pkgs.gnome-music pkgs.monophony];
            })

            (lib.mkIf (cfg.matrixClient == "gnome") {
              home.packages = [pkgs.fractal];
            })

            (lib.mkIf (cfg.calendar == "gnome") {
              home.packages = [pkgs.gnome-calendar];
            })

            (lib.mkIf (cfg.chess == "gnome") {
              home.packages = with pkgs; [gnome-chess gnuchess];
            })

            (lib.mkIf (cfg.whiteboard == "gnome") {
              home.packages = [pkgs.rnote];
            })

            (lib.mkIf (cfg.clock == "gnome") {
              home.packages = [pkgs.gnome-clocks];
            })

            (lib.mkIf (cfg.terminalEmulator == "gnome") {
              programs.ptyxis = {
                enable = true;
              };
              stylix.targets.ptyxis = {
                enable = true;
                profileUUIDs = [ptyxisUUID];
              };
              dconf.settings = {
                "org/gnome/Ptyxis" = {
                  default-profile-uuid = ptyxisUUID;
                  restore-session = true;
                  restore-window-size = true;
                  profile-uuids = [
                    ptyxisUUID
                  ];
                };
              };
            })
          ];
      };
    };
  };
}
