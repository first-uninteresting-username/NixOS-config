# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
# Exercise the installed update entry points without fetching or activating a system.
{
  self,
  lib,
  pkgs,
  ...
}: let
  hostName = "upgrade-fixture";
  flakeRef = "github:first-uninteresting-username/NixOS-config/main#${hostName}";
  makeCheck = pkgs: regression:
    pkgs.testers.runNixOSTest {
      node.specialArgs = {
        userName = "testuser";
        userEnable = true;
        userPassword = "testuser";
        inherit hostName;
      };
      name = "upgrade${lib.optionalString regression "-regression"}";

      # Replace only external rebuild commands; keep the real service and helper scripts.
      node.pkgs = lib.mkForce (pkgs.extend (final: previous: let
        recordingCommand = name:
          final.writeShellApplication {
            inherit name;
            runtimeInputs = [final.coreutils];
            text = ''
              printf '%s\n' ${lib.escapeShellArg name} > /run/update-command
              printf '%s\n' "$@" > /run/update-arguments
              printf '%s\n' "''${NH_OS_FLAKE-}" > /run/update-flake
              id -u > /run/update-uid
              printf '%s\n' ${lib.escapeShellArg name} >> /run/update-invocations
              exit "$(cat /run/update-exit)"
            '';
          };
      in {
        nixos-rebuild = recordingCommand "nixos-rebuild";
        nh = recordingCommand "nh";
        # Mutate the real script so the negative control cannot drift from its command.
        writeShellScript = name: text:
          previous.writeShellScript name (
            if regression && name == "upgrade"
            then builtins.replaceStrings ["set -e"] ["set +e"] text + "\nexit 0\n"
            else text
          );
      }));

      nodes.machine = _: {
        imports = [
          self.nixosModules.user
          self.nixosModules.home-manager
          self.nixosModules.hostname
          self.nixosModules.update
        ];

        # A delayed online target exposes missing Requires/After relationships.
        systemd.services.update-network-gate = {
          wantedBy = ["network-online.target"];
          before = ["network-online.target"];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            if test -e /run/hold-update-network; then
              touch /run/update-network-waiting
              until test -e /run/release-update-network; do sleep 0.1; done
            fi
          '';
        };
      };

      testScript = ''
        import shlex

        flake_ref = "${flakeRef}"
        rebuild_arguments = ["boot", "--flake", flake_ref, "-L"]

        def clear_recording():
            machine.succeed(
                "rm -f /run/update-command /run/update-arguments "
                "/run/update-flake /run/update-uid"
            )

        def assert_command(command, arguments):
            assert machine.succeed("cat /run/update-command").strip() == command
            actual = machine.succeed("cat /run/update-arguments").splitlines()
            assert actual == arguments, actual
            assert machine.succeed("cat /run/update-uid").strip() == "0"

        def assert_service_failure():
            clear_recording()
            machine.succeed("echo 23 > /run/update-exit")
            status, output = machine.execute("systemctl start nixos-upgrade.service")
            assert status != 0, "CHECKS_V2_REGRESSION:upgrade-failure-propagation: " + output
            assert_command("nixos-rebuild", rebuild_arguments)
            assert machine.succeed(
                "systemctl show nixos-upgrade.service -p ExecMainStatus --value"
            ).strip() == "23"
            assert machine.succeed(
                "systemctl show nixos-upgrade.service -p Result --value"
            ).strip() == "exit-code"

        machine.wait_for_unit("multi-user.target")
        machine.succeed("echo 0 > /run/update-exit")

        with subtest("The production timer is enabled and targets the upgrade service"):
            machine.succeed("systemctl is-enabled nixos-upgrade.timer")
            machine.wait_for_unit("nixos-upgrade.timer")
            assert machine.succeed(
                "systemctl show nixos-upgrade.timer -p Unit --value"
            ).strip() == "nixos-upgrade.service"
            machine.succeed("systemctl stop nixos-upgrade.timer")
            machine.fail("test -e /run/update-invocations")

        with subtest("An upgrade waits for the network before rebuilding"):
            machine.succeed("systemctl stop network-online.target update-network-gate.service")
            machine.succeed("touch /run/hold-update-network")
            machine.succeed("systemctl start --no-block nixos-upgrade.service")
            machine.wait_for_file("/run/update-network-waiting")
            machine.succeed(
                "systemctl list-jobs --no-legend | "
                "grep -E 'nixos-upgrade.service +start +waiting'"
            )
            machine.fail("test -e /run/update-command")
            machine.succeed("touch /run/release-update-network")
            machine.wait_until_succeeds("test -e /run/update-command")
            machine.wait_until_succeeds(
                "test $(systemctl show nixos-upgrade.service -p ActiveState --value) = inactive"
            )
            assert_command("nixos-rebuild", rebuild_arguments)

        with subtest("Rebuild failures remain visible, and a later invocation can recover"):
            assert_service_failure()
            machine.succeed("echo 0 > /run/update-exit")
            clear_recording()
            machine.succeed("systemctl start nixos-upgrade.service")
            assert_command("nixos-rebuild", rebuild_arguments)
            assert machine.succeed(
                "systemctl show nixos-upgrade.service -p Result --value"
            ).strip() == "success"

        with subtest("The installed rebuild helper uses this host and propagates failures"):
            for code in [0, 23]:
                clear_recording()
                machine.succeed(f"echo {code} > /run/update-exit")
                status, output = machine.execute("bash -lc rebuild")
                assert status == code, (status, output)
                assert_command("nh", ["os", "boot", flake_ref])
                assert machine.succeed("cat /run/update-flake").strip() == flake_ref

        with subtest("The timer actually invokes the production upgrade service"):
            machine.succeed("echo 0 > /run/update-exit")
            clear_recording()
            before = machine.succeed("cat /run/update-invocations").splitlines()
            # Accelerate scheduling only; preserve the production target and enablement.
            machine.succeed("mkdir -p /run/systemd/system/nixos-upgrade.timer.d")
            override = "\n".join([
                "[Timer]", "OnBootSec=", "OnCalendar=", "OnActiveSec=1s",
                "RandomizedDelaySec=0", "AccuracySec=1us", "",
            ])
            machine.succeed(
                "printf %s " + shlex.quote(override) +
                " > /run/systemd/system/nixos-upgrade.timer.d/test.conf"
            )
            machine.succeed("systemctl daemon-reload; systemctl start nixos-upgrade.timer")
            machine.wait_until_succeeds("test -e /run/update-command")
            machine.wait_until_succeeds(
                "test $(systemctl show nixos-upgrade.service -p ActiveState --value) = inactive"
            )
            machine.succeed("systemctl stop nixos-upgrade.timer")
            assert_command("nixos-rebuild", rebuild_arguments)
            after = machine.succeed("cat /run/update-invocations").splitlines()
            assert after == before + ["nixos-rebuild"], after
      '';
    };
in {
  check = makeCheck pkgs false;
  regression = makeCheck pkgs true;
}
