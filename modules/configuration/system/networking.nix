# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
_: {
  flake = {
    nixosModules.networking-desktop = {
      lib,
      config,
      ...
    }: {
      preservation.preserveAt = lib.mkIf config.custom.preservation.enable {
        "/persist" = {
          directories = [
            "/var/lib/bluetooth"
            "/etc/NetworkManager"
            "/var/lib/NetworkManager"
          ];
        };
      };
      sops.secrets."wifi_password" = {};
      networking = {
        networkmanager = {
          enable = true;
          dns = "none";
        };

        nameservers = ["1.1.1.1" "1.0.0.1"];

        useDHCP = false;

        firewall = {
          enable = true;
        };
      };

      hardware.bluetooth = {
        enable = true;
        powerOnBoot = true;
      };

      systemd.services.nm-wifi-secret = {
        description = "Write WiFi secret to NetworkManager keyfile";
        wantedBy = ["multi-user.target"];
        after = ["sops-nix.service"];
        serviceConfig.Type = "oneshot";
        script = ''
            mkdir -p /etc/NetworkManager/system-connections

            WIFI_PSK=$(cat ${config.sops.secrets."wifi_password".path})

            cat > /etc/NetworkManager/system-connections/malti.nmconnection << EOF
          [connection]
          id=MALTI
          type=wifi

          [wifi]
          ssid=MALTI
          mode=infrastructure

          [wifi-security]
          auth-alg=open
          key-mgmt=wpa-psk
          psk=$WIFI_PSK

          [ipv4]
          method=auto

          [ipv6]
          method=auto
          EOF

            cat > /etc/NetworkManager/system-connections/malti_5g.nmconnection << EOF
          [connection]
          id=MALTI_5G
          type=wifi

          [wifi]
          ssid=MALTI_5G
          mode=infrastructure

          [wifi-security]
          auth-alg=open
          key-mgmt=wpa-psk
          psk=$WIFI_PSK

          [ipv4]
          method=auto

          [ipv6]
          method=auto
          EOF

            chmod 600 /etc/NetworkManager/system-connections/malti.nmconnection
            chmod 600 /etc/NetworkManager/system-connections/malti_5g.nmconnection
            systemctl reload NetworkManager || true
        '';
      };
    };
    nixosModules.secretless-networking-desktop = {
      lib,
      config,
      ...
    }: {
      networking = {
        networkmanager = {
          enable = true;
          dns = "none";
        };

        nameservers = ["1.1.1.1" "1.0.0.1"];

        useDHCP = false;

        firewall = {
          enable = true;
        };
      };

      hardware.bluetooth = {
        enable = true;
        powerOnBoot = true;
      };

      preservation.preserveAt = lib.mkIf config.custom.preservation.enable {
        "/persist" = {
          directories = [
            "/etc/NetworkManager"
            "/var/lib/NetworkManager"
            "/var/lib/bluetooth"
          ];
        };
      };
    };
    nixosModules.networking-minimal = {lib, ...}: {
      networking = {
        networkmanager.enable = true;

        useDHCP = lib.mkDefault false;

        firewall = {
          enable = true;
        };
      };
    };
  };
}
