# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "slick";
  ids = ["slick"];
  module = _: {
    nixos = {
      lib,
      userName,
      preservationEnable,
      ...
    }: {
      preservation.preserveAt = lib.mkIf preservationEnable {
        "/persist" = {
          users.${userName} = {
            directories = [
              ".config/slick"
            ];
          };
        };
      };
    };
    home = {
      pkgs,
      inputs,
      self,
      config,
      ...
    }: {
      xdg.mimeApps.defaultApplications = {
        "x-scheme-handler/slack" = "dev.slick.Slick.desktop";
      };

      home.packages = [
        (self.lib.mkJail {
          inherit pkgs;
          package = inputs.slick.packages.${pkgs.stdenv.hostPlatform.system}.slick.override {
            slackPackage = pkgs.slack;
          };
          gui = true;
          network = true;
          readHostFiles = true;
          homeDirs = [".config/slick" ".cache/slick"];
          readWrite = [config.xdg.userDirs.download];
          dbusOwn = ["dev.slick.Slick"];
          dbusTalk = ["org.freedesktop.secrets"];
        })
      ];
    };
  };
}
