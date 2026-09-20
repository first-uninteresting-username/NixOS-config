# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{self, ...}: {
  perSystem = {pkgs, ...}: let
    checkname = "agents";
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
          self.nixosModules.agents
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
        machine.wait_for_unit("multi-user.target")

        machine.succeed("su - ${username} -c 'opencode --version'")
        machine.succeed("su - ${username} -c 'kilocode --version'")
      '';
    };
  };
}
