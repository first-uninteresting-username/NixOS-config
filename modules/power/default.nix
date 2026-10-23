# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "power";
  ids = ["power"];
  state = {
    nixos.directories = [
      "/var/lib/power-profiles-daemon"
    ];
  };
  module = _: {
    nixos = _: {
      services = {
        upower.enable = true;
        power-profiles-daemon.enable = true;
        # Here, because it helps to reduce power usage
        irqbalance.enable = true;
      };
    };
  };
}
