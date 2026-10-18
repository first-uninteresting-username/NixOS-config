# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "host-wall-e";
  ids = ["host-wall-e"];
  module = _: {
    nixos = {lib, ...}: {
      users.users.root = {
        initialPassword = "nixos";
        hashedPassword = lib.mkForce null;
      };
    };
  };
  packages = {
    self,
    lib,
    system,
    ...
  }:
    lib.optionalAttrs (system == "x86_64-linux") {default = self.nixosConfigurations.wall-e.config.system.build.isoImage;};
}
