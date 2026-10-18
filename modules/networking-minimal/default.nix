# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "networking-minimal";
  ids = ["networking-minimal"];
  module = _: {
    nixos = {lib, ...}: {
      networking = {
        networkmanager.enable = true;

        useDHCP = lib.mkDefault false;

        firewall = {
          enable = true;
        };
      };
    };
  };
}
