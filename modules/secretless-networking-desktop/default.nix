# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "secretless-networking-desktop";
  ids = ["secretless-networking-desktop"];
  module = _: {
    nixos = {
      lib,
      preservationEnable,
      ...
    }: {
      networking = {
        networkmanager = {
          enable = true;
          dns = "none";
        };

        nameservers = ["1.1.1.1" "1.0.0.1"];

        useDHCP = false;

        firewall = {
          enable = true;
        };
      };

      hardware.bluetooth = {
        enable = true;
        powerOnBoot = true;
      };

      preservation.preserveAt = lib.mkIf preservationEnable {
        "/persist" = {
          directories = [
            "/etc/NetworkManager"
            "/var/lib/NetworkManager"
            "/var/lib/bluetooth"
          ];
        };
      };
    };
  };
}
