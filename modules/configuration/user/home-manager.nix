# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{inputs, ...}: {
  flake = {
    nixosModules.home-manager = {config, ...}: {
      imports = [
        inputs.home-manager.nixosModules.home-manager
      ];
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "backup";
      };
      home-manager.users.${config.custom.user.name} = {
        osConfig,
        lib,
        ...
      }: {
        programs.home-manager.enable = true;
        home.homeDirectory = "/home/${osConfig.custom.user.name}";
        home.enableNixpkgsReleaseCheck = false;
        home.stateVersion = lib.mkDefault osConfig.system.stateVersion;
      };
    };
  };
}
