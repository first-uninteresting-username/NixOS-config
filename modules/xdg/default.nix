# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "xdg";
  ids = ["xdg"];
  state = {
    home.directories = [
      ".config"
      ".local/share"
      ".local/state"
      "Downloads"
      "Documents"
      "Music"
      "Pictures"
      "Templates"
      "Videos"
      "Projects"
      "Games"
    ];
  };
  module = _: {
    home = {
      config,
      userName,
      ...
    }: let
      homeBase = config.home.homeDirectory;
    in {
      systemd.user.tmpfiles.rules = [
        "d ${homeBase}/Games 0755 ${userName} ${userName} -"
      ];
      xdg = {
        enable = true;
        userDirs = {
          enable = true;
          createDirectories = true;
          desktop = null;
          download = "${homeBase}/Downloads";
          documents = "${homeBase}/Documents";
          pictures = "${homeBase}/Pictures";
          music = "${homeBase}/Music";
          publicShare = null;
          templates = "${homeBase}/Templates";
          videos = "${homeBase}/Videos";
          projects = "${homeBase}/Projects";
          extraConfig = {
            GAMES = "${homeBase}/Games";
          };
        };
      };
    };
  };
}
