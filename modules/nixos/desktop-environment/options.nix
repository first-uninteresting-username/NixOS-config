# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{self, ...}: {
  flake = {
    nixosModules.DE = {
      lib,
      config,
      ...
    }: let
      desktopEnvType = lib.types.nullOr (lib.types.enum [
        "gnome"
        #"plasma"
        "blank"
      ]);
      functionalities = [
        "fileManager"
        "terminalEmulator"
        "documentViewer"
        "archiveTool"
        "screenshotUtility"
        "systemMonitor"
        "textEditor"
        "imageViewer"
        "paintingApp"
        "calculator"
        "characterSelector"
        "isoWriter"
        "diskUsageViewer"
        "musicPlayer"
        "matrixClient"
        "calendar"
        "chess"
        "whiteboard"
        "clock"
      ];
      cfg = config.custom.DE;
    in {
      imports = [
        self.nixosModules.GNOME
        self.nixosModules.DE-programs-gnome
      ];
      options.custom.DE = {
        enable = lib.mkEnableOption "DE configuration";
        name = lib.mkOption {
          type = desktopEnvType;
          default = null;
          example = "gnome";
          description = "Name of the desktop envinronement to be enabled and configured";
        };
        programs = lib.genAttrs functionalities (
          name:
            lib.mkOption {
              type = desktopEnvType;
              default = cfg.name;
              example = "gnome";
              description = ''
                Which desktop-environment-specific utility to use for "${name}".
                Set to "gnome" to pull in that DE's tool, or null to disable/skip.
              '';
            }
        );
      };
    };
  };
}
