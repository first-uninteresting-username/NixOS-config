# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
# Reboot with ephemeral root state and verify preserved system and user files survive.
{
  self,
  pkgs,
  ...
}: let
  mkTest = pkgs: loseUserState:
    pkgs.testers.runNixOSTest {
      node.specialArgs = {
        userName = "testuser";
        userEnable = true;
        userPassword = "public-test-password";
        preservationEnable = true;
      };
      name =
        if loseUserState
        then "persistence-without-user-state"
        else "persistence";

      nodes.machine = {lib, ...}: {
        imports = [
          self.nixosModules.user
          self.nixosModules.home-manager
          self.nixosModules.preservation
        ];

        services.openssh = {
          enable = true;
          hostKeys = [
            {
              type = "ed25519";
              path = "/etc/ssh/ssh_host_ed25519_key";
            }
          ];
        };

        # The root and home are recreated on every boot. Only this extra disk survives.
        virtualisation = {
          diskImage = null;
          memorySize = 1024;
          emptyDiskImages = [
            {
              size = 128;
              driveConfig.deviceExtraOpts.serial = "checks-v2-persist";
            }
          ];
          fileSystems = {
            "/nix" = {
              device = "tmpfs";
              fsType = "tmpfs";
              neededForBoot = true;
            };
            "/persist" = {
              device = "/dev/disk/by-id/virtio-checks-v2-persist";
              fsType = "ext4";
              autoFormat = true;
              neededForBoot = true;
            };
          };
        };

        preservation.preserveAt."/persist".users.testuser.directories =
          lib.mkIf loseUserState (lib.mkForce []);
      };

      testScript = ''
        machine.start(allow_reboot=True)
        machine.wait_for_unit("multi-user.target")
        machine.wait_for_unit("sshd.service")
        assert machine.succeed("findmnt -n -o FSTYPE /").strip() == "tmpfs"
        machine.succeed("mountpoint /persist")

        boot_id = machine.succeed("cat /proc/sys/kernel/random/boot_id").strip()
        machine_id = machine.succeed("cat /etc/machine-id").strip()
        assert machine_id, "machine-id must be populated before reboot"
        host_key = machine.succeed("sha256sum /etc/ssh/ssh_host_ed25519_key").split()[0]

        machine.succeed("su - testuser -c 'mkdir -p ~/persist; printf user-state > ~/persist/checks-v2'")
        machine.succeed("printf system-state > /var/lib/nixos/checks-v2")
        machine.succeed("printf ephemeral > /var/lib/checks-v2-ephemeral")
        machine.succeed("su - testuser -c 'printf ephemeral > ~/checks-v2-ephemeral'")
        machine.succeed("sync")

        machine.reboot()
        machine.wait_for_unit("multi-user.target")
        machine.wait_for_unit("sshd.service")
        assert machine.succeed("findmnt -n -o FSTYPE /").strip() == "tmpfs"
        assert machine.succeed("cat /proc/sys/kernel/random/boot_id").strip() != boot_id

        with subtest("User and system state survive a fresh root"):
            status, _ = machine.execute("test -f /home/testuser/persist/checks-v2")
            assert status == 0, "CHECKS_V2_REGRESSION:persistence-user-state"
            assert machine.succeed("su - testuser -c 'cat ~/persist/checks-v2'").strip() == "user-state"
            assert machine.succeed("cat /var/lib/nixos/checks-v2").strip() == "system-state"
            machine.succeed("su - testuser -c 'test -w ~/persist/checks-v2'")
            machine.fail("test -e /var/lib/checks-v2-ephemeral")
            machine.fail("test -e /home/testuser/checks-v2-ephemeral")

        with subtest("Machine and SSH identities survive"):
            assert machine.succeed("cat /etc/machine-id").strip() == machine_id
            assert machine.succeed("sha256sum /etc/ssh/ssh_host_ed25519_key").split()[0] == host_key
      '';
    };
in {
  check = mkTest pkgs false;
  regression = mkTest pkgs true;
}
