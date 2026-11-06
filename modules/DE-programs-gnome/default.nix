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
    }: {
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
    };
  };
}
