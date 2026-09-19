# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
_: {
  flake = {
    nixosModules.xdg = {
      lib,
      config,
      ...
    }: {
      preservation.preserveAt = lib.mkIf config.custom.preservation.enable {
        "/persist" = {
          users.${config.custom.user.name} = {
            directories = [
              ".config"
              ".local/share"
              ".local/state"
            ];
          };
        };
      };
      home-manager.users.${config.custom.user.name} = {
        config,
        osConfig,
        ...
      }: let
        homeBase =
          if osConfig.custom.preservation.enable
          then "${config.home.homeDirectory}/persist"
          else config.home.homeDirectory;
      in {
        systemd.user.tmpfiles.rules = [
          "d ${homeBase}/Games 0755 ${osConfig.custom.user.name} ${osConfig.custom.user.name} -"
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
            music = null;
            publicShare = null;
            templates = "${homeBase}/Templates";
            videos = "${homeBase}/Videos";
            projects = "${homeBase}/Projects";
            extraConfig = {
              XDG_GAMES_DIR = "${homeBase}/Games";
            };
          };
        };
      };
    };
  };
}
