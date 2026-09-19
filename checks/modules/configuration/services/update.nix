# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{self, ...}: {
  perSystem = {pkgs, ...}: let
    checkname = "update";
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
          self.nixosModules.hostname
          self.nixosModules.update
        ];
        custom = {
          hostname = username;
          user = {
            enable = true;
            name = username;
            password = username;
          };
        };
        virtualisation.writableStore = true;
        virtualisation.memorySize = 2048;

        nix = {
          settings = {
            experimental-features = [
              "nix-command"
              "flakes"
            ];
          };
        };
      };

      testScript = ''
        machine.wait_for_unit("default.target")

        machine.succeed("systemctl start nh-clean.service")
        machine.succeed("systemctl start nix-optimise.service")

        services = ["nh-clean.service", "nixos-upgrade.service", "nix-optimise.service"]

        for service in services:
              machine.succeed(f"systemctl cat {service}")

        machine.wait_for_unit("nix-daemon.socket")
        machine.succeed("systemctl start nix-optimise.service", timeout=600)
        machine.succeed("systemctl start nh-clean.service", timeout=300)
      '';
    };
  };
}
