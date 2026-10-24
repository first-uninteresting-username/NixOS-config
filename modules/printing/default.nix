# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "printing";
  ids = ["printing"];
  state = {
    nixos.directories = [
      "/var/lib/cups"
    ];
  };
  module = _: {
    nixos = _: {
      users.groups.netdev = {};
      services.avahi = {
        enable = true;
        nssmdns4 = true;
        openFirewall = true;
      };

      services.printing = {
        enable = true;
      };
    };
  };
}
