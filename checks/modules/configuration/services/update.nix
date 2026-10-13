# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  self,
  withSystem,
  lib,
  ...
}: let
  hostName = "upgrade-fixture";
  flakeRef = "github:first-uninteresting-username/NixOS-config/main#${hostName}";
  makeCheck = pkgs: regression:
    pkgs.testers.runNixOSTest {
      name = "upgrade${lib.optionalString regression "-regression"}";

      # Keep the production ExecStart script, replacing its external command only.
      node.pkgs = lib.mkForce (pkgs.extend (final: _: let
        recordingCommand = name:
          final.writeShellApplication {
            inherit name;
            runtimeInputs = [final.coreutils];
            text = ''
              printf '%s\n' ${lib.escapeShellArg name} > /run/upgrade-command
              printf '%s\n' "$@" > /run/upgrade-arguments
              cat /proc/sys/kernel/hostname > /run/upgrade-host
              exit "$(cat /run/upgrade-exit)"
            '';
          };
      in {
        nixos-rebuild = recordingCommand "nixos-rebuild";
        nh = recordingCommand "nh";
      }));

      nodes.machine = {lib, ...}: {
        imports = [
          self.nixosModules.hostname
          self.nixosModules.update
        ];
        custom.hostname = hostName;

        # A representative regression: incorrectly treating command failure as success.
        systemd.services.nixos-upgrade.serviceConfig.SuccessExitStatus =
          lib.mkIf regression [23];
      };

      testScript = ''
        machine.wait_for_unit("multi-user.target")
        machine.succeed("echo 0 > /run/upgrade-exit")
        machine.succeed("systemctl start nixos-upgrade.service")

        command = machine.succeed("cat /run/upgrade-command").strip()
        assert command == "nixos-rebuild", command
        arguments = machine.succeed("cat /run/upgrade-arguments").splitlines()
        assert arguments == ["boot", "--flake", "${flakeRef}", "-L"], arguments
        assert machine.succeed("cat /run/upgrade-host").strip() == "${hostName}"
        environment = machine.succeed("bash -l -c 'printf %s \"$NH_OS_FLAKE\"'")
        assert environment == "${flakeRef}", environment

        machine.succeed("echo 23 > /run/upgrade-exit")
        upgrade_status, upgrade_output = machine.execute(
            "systemctl start nixos-upgrade.service"
        )
        assert upgrade_status != 0, (
            "CHECKS_V2_REGRESSION:upgrade-failure-propagation " + upgrade_output
        )
        status = machine.succeed(
            "systemctl show nixos-upgrade.service -p ExecMainStatus --value"
        ).strip()
        assert status == "23", status
        result = machine.succeed(
            "systemctl show nixos-upgrade.service -p Result --value"
        ).strip()
        assert result == "exit-code", result
      '';
    };
in {
  perSystem = {
    pkgs,
    system,
    ...
  }: {
    checks = lib.optionalAttrs (system == "x86_64-linux") {
      upgrade = makeCheck pkgs false;
    };
  };

  flake.regressionChecks.x86_64-linux.upgrade =
    withSystem "x86_64-linux" ({pkgs, ...}: makeCheck pkgs true);
}
