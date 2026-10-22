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
      self,
      config,
      ...
    }: let
      sandbox = package: appId:
        self.lib.mkJail {
          inherit pkgs package;
          gui = true;
          homeDirs = [".config/${appId}" ".local/share/${appId}" ".cache/${appId}"];
          readWrite = builtins.filter (path: path != null) (with config.xdg.userDirs; [
            documents
            download
            pictures
            videos
          ]);
          dbusOwn = [appId "${appId}.*"];
        };
      ptyxisUUID = "00000000-0000-0000-0000-000000000000";
    in {
      # GNOME hosts share the complete utility set; Impression needs x86-only syslinux.
      home.packages =
        (with pkgs; [
          nautilus
          (sandbox papers "org.gnome.Papers")
          (sandbox file-roller "org.gnome.FileRoller")
          kooha
          (sandbox gradia "be.alexandervanhee.gradia")
          mission-center
          (sandbox gnome-text-editor "org.gnome.TextEditor")
          (sandbox loupe "org.gnome.Loupe")
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
          (sandbox rnote "com.github.flxzt.rnote")
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
