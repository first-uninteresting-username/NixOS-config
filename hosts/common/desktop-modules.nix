# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  pkgs,
  config,
  self,
  hostName,
  lib,
  ...
}: {
  imports = [
    self.nixosModules.DE
    self.nixosModules.user
    self.nixosModules.hostname
    self.nixosModules.stylix
    self.nixosModules.preservation
    self.nixosModules.shell
  ];
  sops.secrets."sudo_password/${config.custom.hostname}" = {
    neededForUsers = true;
  };

  custom = {
    user = {
      enable = true;
      name = "nixi";
      hashedPasswordFile = config.sops.secrets."sudo_password/${config.custom.hostname}".path;
    };
    hostname = hostName;
    stylix = {
      enable = true;
      image = {
        width = lib.mkDefault "2560";
        height = lib.mkDefault "1440";
        enable = true;
      };
      base16Scheme = "gruvbox-dark";
      icons = {
        package = pkgs.morewaita-icon-theme;
        name = "MoreWaita";
      };
    };
    preservation.enable = true;
    shell = {
      enable = true;
      name = "nushell";
    };
    DE = {
      enable = true;
      name = "gnome";
    };
  };
}
