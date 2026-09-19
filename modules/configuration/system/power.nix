# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
_: {
  flake = {
    nixosModules.power = {
      lib,
      config,
      ...
    }: {
      preservation.preserveAt = lib.mkIf config.custom.preservation.enable {
        "/persist" = {
          directories = [
            "/var/lib/power-profiles-daemon"
          ];
        };
      };

      services = {
        upower.enable = true;
        power-profiles-daemon.enable = true;
        # Here, because it helps to reduce power usage
        irqbalance.enable = true;
      };
    };
  };
}
