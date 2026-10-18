# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "DE-programs-gnome";
  ids = ["GNOME"];
  module = _: {
    home = {
      lib,
      pkgs,
      ...
    }: let
      ptyxisUUID = "00000000-0000-0000-0000-000000000000";
    in {
      # GNOME hosts share the complete utility set; Impression needs x86-only syslinux.
      home.packages =
        (with pkgs; [
          nautilus
          papers
          file-roller
          kooha
          gradia
          mission-center
          gnome-text-editor
          loupe
          pinta
          gnome-calculator
          gnome-characters
          baobab
          gnome-music
          monophony
          fractal
          gnome-calendar
          gnome-chess
          gnuchess
          rnote
          gnome-clocks
        ])
        ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [pkgs.impression];
      programs.ptyxis.enable = true;
      stylix.targets.ptyxis = {
        enable = true;
        profileUUIDs = [ptyxisUUID];
      };
      dconf.settings."org/gnome/Ptyxis" = {
        default-profile-uuid = ptyxisUUID;
        restore-session = true;
        restore-window-size = true;
        profile-uuids = [ptyxisUUID];
      };
    };
  };
}
