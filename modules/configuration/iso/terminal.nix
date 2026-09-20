# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{self, ...}: {
  flake = {
    nixosModules.iso-terminal = {modulesPath, ...}: {
      imports = [
        (modulesPath + "/installer/cd-dvd/installation-cd-base.nix")
        self.nixosModules.iso
      ];
    };
  };
}
