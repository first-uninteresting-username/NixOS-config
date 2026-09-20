# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{self, ...}: {
  perSystem = {pkgs, ...}: let
    checkname = "wayland";
    username = "testuser";
  in {
    checks.${checkname} = pkgs.testers.runNixOSTest {
      name = checkname;

      requiredFeatures.kvm = pkgs.stdenv.hostPlatform.isx86_64;

      nodes.machine = {...}: {
        imports = [
          self.nixosModules.user
          self.nixosModules.preservation
          self.nixosModules.home-manager
          self.nixosModules.wayland
        ];
        custom = {
          user = {
            enable = true;
            name = username;
            password = username;
          };
        };
      };

      testScript = ''
        machine.succeed("wl-copy --version")
        machine.succeed("wl-paste --version")

        machine.wait_for_unit("dbus.service")
        machine.succeed("systemctl start polkit.service")
        machine.wait_for_unit("polkit.service")
      '';
    };
  };
}
