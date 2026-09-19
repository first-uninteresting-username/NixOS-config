# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  pkgs,
  self,
  hostName,
  ...
}: {
  imports = [
    self.nixosModules.user
    self.nixosModules.hostname
    self.nixosModules.stylix
    self.nixosModules.preservation
    self.nixosModules.shell
  ];

  custom = {
    user = {
      enable = true;
      name = "nixos";
      # password is `nixos`
      hashedPassword = "$y$j9T$e3RBMYwLteags209/SMBP0$f4bZILjV/MjNCquJFQmxL55.q6SdtN.gbATDv7Mds50";
    };
    hostname = hostName;
    stylix = {
      enable = true;
      base16Scheme = "gruvbox-dark";
      icons = {
        package = pkgs.morewaita-icon-theme;
        name = "MoreWaita";
      };
    };
    preservation.enable = false;
    shell = {
      enable = true;
      name = "nushell";
    };
  };
}
