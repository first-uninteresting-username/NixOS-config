# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  self,
  lib,
  ...
}: let
  # Previews nisha's XFCE desktop in a local window; the real host is an aarch64 server.
  nishaPreview = (self.lib.modules.mkHost (import ../hosts/nisha.nix // {system = "x86_64-linux";})).extendModules {
    modules = [
      {
        virtualisation.vmVariant = {
          virtualisation = {
            memorySize = 4096;
            cores = 2;
            resolution = {
              x = 1600;
              y = 900;
            };
          };
          # The VM has no age identity, so the user gets a fixed password and logs in automatically.
          users.users.nixi = {
            hashedPasswordFile = lib.mkForce null;
            password = "nixos";
          };
          services.displayManager.autoLogin = {
            enable = true;
            user = "nixi";
          };
        };
      }
    ];
  };
in {
  perSystem = {system, ...}: {
    apps =
      {john.program = "${self.nixosConfigurations.john.config.system.build.vm}/bin/run-john-vm";}
      // lib.optionalAttrs (system == "x86_64-linux") {
        nisha.program = "${nishaPreview.config.system.build.vm}/bin/run-nisha-vm";
      };
  };
}
