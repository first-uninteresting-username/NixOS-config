# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{self, ...}: {
  flake = {
    nixosModules.iso-graphical = {
      pkgs,
      modulesPath,
      ...
    }: {
      imports = [
        (modulesPath + "/installer/cd-dvd/installation-cd-graphical-base.nix")
        self.nixosModules.iso
      ];

      environment.defaultPackages = with pkgs; [
        parted
        diskus
        nvme-cli
        hdparm
        sdparm
        pciutils
        usbutils
        lshw
        dmidecode
        mesa-demos
        cryptsetup
        vlc
      ];
    };
  };
}
