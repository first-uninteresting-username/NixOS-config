# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{lib, ...}: {
  users.users.root = {
    initialPassword = "nixos";
    hashedPassword = lib.mkForce null;
  };
  virtualisation.vmVariant = {
    virtualisation = {
      memorySize = 4096;
      cores = 2;
    };
  };
}
