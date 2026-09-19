# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{self, ...}: {
  flake = {
    nixosModules.iso = {
      config,
      pkgs,
      ...
    }: {
      boot.zfs.forceImportRoot = false;

      environment.defaultPackages = with pkgs; [
        nano
        netcat
        disko
        nixos-anywhere
        micro
      ];

      isoImage.contents = [
        {
          source = self.outPath;
          target = "/flake-source";
        }
      ];

      systemd.tmpfiles.rules = [
        "C /etc/nixos - - - - /flake-source"
        "Z /etc/nixos 0777 ${config.custom.user.name} ${config.custom.user.name} -"
      ];

      home-manager.users.${config.custom.user.name} = {
        osConfig,
        lib,
        ...
      }: {
        home.stateVersion = lib.mkForce osConfig.system.stateVersion;
      };
    };
  };
}
