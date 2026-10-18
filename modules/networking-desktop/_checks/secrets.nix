# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
# Decrypt disposable credentials and verify NetworkManager loads the generated profiles.
{
  self,
  inputs,
  pkgs,
  ...
}: let
  mkTest = pkgs: skipReload: let
    # This identity and password are disposable public test material, unrelated to hosts.
    fixture =
      pkgs.runCommand "networkmanager-public-sops-fixture" {
        nativeBuildInputs = [pkgs.age pkgs.sops];
      } ''
        mkdir -p "$out"
        age-keygen -o "$out/age-key.txt" 2>/dev/null
        recipient=$(age-keygen -y "$out/age-key.txt")
        printf 'wifi_password: checks-v2-public-wifi-password\n' > fixture.yaml
        sops --encrypt --age "$recipient" fixture.yaml > "$out/secrets.yaml"
        rm fixture.yaml
      '';
  in
    pkgs.testers.runNixOSTest {
      node.specialArgs = {
        userName = "testuser";
        userEnable = true;
        userPassword = "public-test-password";
      };
      name =
        if skipReload
        then "networkmanager-secrets-without-reload"
        else "networkmanager-secrets";

      nodes.machine = {lib, ...}: {
        imports = [
          self.nixosModules.user
          self.nixosModules.home-manager
          self.nixosModules.preservation
          self.nixosModules.networking-desktop
          inputs.sops-nix.nixosModules.sops
        ];

        sops = {
          defaultSopsFile = "${fixture}/secrets.yaml";
          # The encrypted fixture is produced at build time, without evaluation-time builds.
          validateSopsFiles = false;
          useSystemdActivation = true;
          age = {
            keyFile = "/run/checks-v2/age-key.txt";
            generateKey = false;
            sshKeyPaths = [];
          };
          gnupg.sshKeyPaths = [];
        };
        system.activationScripts.publicTestAgeKey = ''
          install -Dm600 ${fixture}/age-key.txt /run/checks-v2/age-key.txt
        '';
        environment.systemPackages = [pkgs.python3];

        # Preserve the generated files but prevent NetworkManager from ingesting them.
        systemd.services.nm-wifi-secret.path = lib.mkIf skipReload (lib.mkForce [
          (pkgs.writeShellScriptBin "nmcli" "exit 0")
          pkgs.coreutils
        ]);
      };

      testScript = ''
        import time

        machine.start()
        machine.wait_for_unit("sops-install-secrets.service")
        machine.wait_for_unit("NetworkManager.service")
        machine.wait_until_succeeds("test -f /etc/NetworkManager/system-connections/malti_5g.nmconnection")
        machine.wait_until_succeeds("test $(systemctl show nm-wifi-secret.service -p ActiveState --value) = inactive")
        machine.succeed("test $(systemctl show nm-wifi-secret.service -p Result --value) = success")

        with subtest("Encrypted fixture produces private NetworkManager keyfiles"):
            machine.succeed("test $(stat -c '%a:%U:%G' /run/secrets/wifi_password) = 400:root:root")
            machine.succeed("python3 - <<'PY'\n"
                "import configparser, os, stat\n"
                "for basename, ssid in [('malti', 'MALTI'), ('malti_5g', 'MALTI_5G')]:\n"
                "    path = '/etc/NetworkManager/system-connections/' + basename + '.nmconnection'\n"
                "    info = os.stat(path)\n"
                "    assert stat.S_IMODE(info.st_mode) == 0o600\n"
                "    assert info.st_uid == 0 and info.st_gid == 0\n"
                "    profile = configparser.ConfigParser()\n"
                "    profile.read(path)\n"
                "    assert profile['connection']['id'] == ssid\n"
                "    assert profile['connection']['type'] == 'wifi'\n"
                "    assert profile['wifi']['ssid'] == ssid\n"
                "    assert profile['wifi']['mode'] == 'infrastructure'\n"
                "    assert profile['wifi-security']['key-mgmt'] == 'wpa-psk'\n"
                "    assert profile['wifi-security']['psk'] == 'checks-v2-public-wifi-password'\n"
                "    assert profile['ipv4']['method'] == 'auto'\n"
                "    assert profile['ipv6']['method'] == 'auto'\n"
                "PY")

        with subtest("NetworkManager loads both generated profiles"):
            expected_profiles = {"MALTI", "MALTI_5G"}
            for _ in range(30):
                status, output = machine.execute("nmcli --get-values NAME connection show")
                if status != 0:
                    raise RuntimeError(f"Cannot query NetworkManager profiles: {status}: {output}")
                profiles = set(output.splitlines())
                if expected_profiles <= profiles:
                    break
                time.sleep(1)
            assert expected_profiles <= profiles, "CHECKS_V2_REGRESSION:networkmanager-profile-load"
            for ssid in ["MALTI", "MALTI_5G"]:
                assert machine.succeed(f"nmcli --get-values connection.id connection show {ssid}").strip() == ssid
                assert machine.succeed(f"nmcli --get-values connection.type connection show {ssid}").strip() == "802-11-wireless"
                assert machine.succeed(f"nmcli --get-values 802-11-wireless.ssid connection show {ssid}").strip() == ssid
      '';
    };
in {
  check = mkTest pkgs false;
  regression = mkTest pkgs true;
}
