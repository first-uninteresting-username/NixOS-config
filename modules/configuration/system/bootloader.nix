# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
_: {
  flake = {
    nixosModules.bootloader = _: {
      stylix.targets.limine.enable = true;

      boot.loader = {
        efi = {
          canTouchEfiVariables = true;
          efiSysMountPoint = "/boot";
        };

        limine = {
          enable = true;
          efiSupport = true;
          biosSupport = false;
          maxGenerations = 10;

          # I don't use secure boot on my PCs anyway, but it is nice to have it I guess
          secureBoot = {
            enable = true;
            autoGenerateKeys = true;
            autoEnrollKeys = {
              enable = true;
              extraArgs = [
                "--firmware-builtin"
              ];
            };
          };
        };
      };
    };
  };
}
