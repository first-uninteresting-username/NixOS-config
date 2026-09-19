# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{self, ...}: {
  imports = [
    self.nixosModules.DE
    ../common/iso-modules.nix
  ];
  custom = {
    DE = {
      enable = true;
      name = "gnome";
    };
    stylix.image = {
      width = "1920";
      height = "1080";
      enable = true;
    };
  };
}
