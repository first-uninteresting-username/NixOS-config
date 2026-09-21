# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{self, ...}: {
  perSystem = {pkgs, ...}: let
    checkname = "windows-vm";
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
          self.nixosModules.windows-vm
        ];
        custom = {
          user = {
            enable = true;
            name = username;
            password = username;
          };
        };

        virtualisation.memorySize = 2048;
      };

      testScript = ''
        machine.wait_for_unit("multi-user.target")

        machine.wait_until_succeeds("virsh list")
        machine.succeed("systemctl is-active libvirtd.service")

        machine.succeed("command -v virt-manager")
        machine.succeed("id testuser | grep -q libvirtd")
        machine.succeed("id testuser | grep -q kvm")
      '';
    };
  };
}
