# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{self, ...}: {
  perSystem = {pkgs, ...}: let
    checkname = "programs";
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
          self.nixosModules.programs-desktop
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
        unit = "ananicy-cpp.service"

        machine.wait_for_unit(unit)
        machine.succeed(f"systemctl is-active {unit}")
        machine.succeed(
            f"test \"$(systemctl show -p SubState --value {unit})\" = running"
        )

        machine.succeed("pgrep -x ananicy-cpp")

        machine.fail(f"journalctl -u {unit} -b -p err --no-pager | grep .")

        machine.succeed("test -d /etc/ananicy.d")
        machine.succeed("find /etc/ananicy.d -name '*.rules' | grep -q .")

        machine.succeed("install -m0755 \"$(command -v sleep)\" /tmp/gcc")
        machine.succeed(
            "systemd-run --unit=ananicy-probe --collect /tmp/gcc 600"
        )

        machine.wait_until_succeeds(
            "pid=$(systemctl show -p MainPID --value ananicy-probe); "
            "test \"$pid\" -gt 0 && "
            "test \"$(ps -o ni= -p \"$pid\" | tr -d ' ')\" -gt 0",
            timeout=90,
        )

        machine.succeed("systemctl stop ananicy-probe")
      '';
    };
  };
}
