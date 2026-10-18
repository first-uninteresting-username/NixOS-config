# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "home-manager";
  ids = ["home-manager"];
  module = _: {
    nixos = _: {
      home-manager.backupFileExtension = "backup";
    };
    home = {
      homeStateVersion,
      lib,
      userName,
      ...
    }: {
      programs.home-manager.enable = true;
      home.username = userName;
      home.homeDirectory = "/home/${userName}";
      home.enableNixpkgsReleaseCheck = false;
      home.stateVersion = lib.mkDefault homeStateVersion;
    };
  };
}
