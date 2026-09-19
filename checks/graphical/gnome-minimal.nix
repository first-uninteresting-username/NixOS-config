# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{self, ...}: {
  perSystem = {
    pkgs,
    lib,
    system,
    ...
  }: let
    checkname = "gnome-minimal";
  in {
    checks = lib.optionalAttrs (system == "x86_64-linux") {
      ${checkname} = pkgs.testers.runNixOSTest {
        name = checkname;

        nodes.machine = {...}: {
          _module.args.inputs = self.inputs;

          imports = [
            self.nixosModules.DE
            self.nixosModules.user
            self.nixosModules.stylix
            self.nixosModules.preservation
            self.nixosModules.home-manager
          ];

          custom = {
            user = {
              enable = true;
              name = "testuser";
              password = "testuser";
            };
            stylix = {
              enable = true;
              image.enable = true;
            };
            preservation.enable = false;
            DE = {
              enable = true;
              name = "gnome";
            };
          };

          virtualisation = {
            cores = 2;
            memorySize = 4096;
          };
        };

        testScript = ''
          machine.wait_for_unit("graphical.target")
          machine.wait_for_unit("display-manager.service")
        '';
      };
    };
  };
}
