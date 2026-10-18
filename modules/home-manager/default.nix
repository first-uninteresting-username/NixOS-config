# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "home-manager";
  ids = ["home-manager"];
  docs = {
    userName,
    role,
  }: ''
    Home Manager manages the home configuration for `${userName}`.
    ${
      if role == "nixos"
      then "The NixOS configuration embeds this user's home configuration."
      else "This host produces a standalone Home Manager activation package."
    }

    Run `open-docs` to read this host's documentation in a terminal browser.
    The application menu also contains a documentation launcher for a graphical browser.
  '';
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
