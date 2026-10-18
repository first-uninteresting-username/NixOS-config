# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "iso-terminal";
  ids = ["iso-terminal"];
  module = _: {
    nixos = {modulesPath, ...}: {
      imports = [
        (modulesPath + "/installer/cd-dvd/installation-cd-base.nix")
      ];
    };
  };
}
