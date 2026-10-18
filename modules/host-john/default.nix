# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "host-john";
  ids = ["host-john"];
  module = _: {
    nixos = {lib, ...}: {
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
    };
  };
  packages = {
    self,
    lib,
    system,
    ...
  }:
    lib.optionalAttrs (system == "x86_64-linux") {default = self.nixosConfigurations.john.config.system.build.isoImage;};
}
