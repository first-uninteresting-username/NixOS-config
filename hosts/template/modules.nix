# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{hostName, ...}: {
  imports = [
    self.nixosModules.hostname
    self.nixosModules.preservation
    # Import modules here
  ];

  custom = {
    hostname = hostName;
    preservation.enable = false; # or true, without that things will break
    # Configure modules here
  };
}
