# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}: let
  domain = "headscale.iameasytoremember.com";
  # Owner of the preauth keys that register hosts.
  tailnetUser = "nixi";
in
  mkModule {
    name = "headscale";
    ids = ["headscale"];
    state.nixos.directories = [
      "/var/lib/headscale"
      "/var/lib/headplane"
      "/var/lib/tailscale"
      "/var/lib/caddy"
    ];
    module = _: {
      nixos = {
        config,
        lib,
        pkgs,
        ...
      }: let
        headscale = config.services.headscale;
        localUrl = "http://${headscale.address}:${toString headscale.port}";
        authKeyDir = "/run/headscale-local-authkey";
        cookieSecret = "${config.services.headplane.settings.server.data_path}/cookie-secret";
      in {
        services.headscale = {
          enable = true;
          settings = {
            server_url = "https://${domain}";
            dns = {
              magic_dns = true;
              base_domain = "tail.iameasytoremember.com";
              # Keep each host's own resolvers; Tailscale adds split DNS for the base domain.
              override_local_dns = false;
            };
            # Embedded DERP relay; Tailscale's public relays stay in the map as fallback.
            derp.server = {
              enabled = true;
              region_id = 999;
              region_code = "nisha";
              region_name = "nisha (Frankfurt)";
              stun_listen_addr = "0.0.0.0:3478";
              automatically_add_embedded_derp_region = true;
            };
          };
        };

        services.headplane = {
          enable = true;
          settings.server = {
            base_url = "https://${domain}";
            cookie_secret_path = cookieSecret;
          };
        };

        # Headplane signs sessions with a random host-local secret created on first start.
        systemd.services.headplane.preStart = ''
          if [ ! -s ${cookieSecret} ]; then
            umask 077
            ${lib.getExe' pkgs.coreutils "od"} -An -N16 -tx1 /dev/urandom \
              | ${lib.getExe' pkgs.coreutils "tr"} -d ' \n' > ${cookieSecret}
          fi
        '';

        # Headscale serves the control plane and DERP; Headplane serves itself under /admin.
        services.caddy = {
          enable = true;
          virtualHosts.${domain}.extraConfig = ''
            handle /admin* {
              reverse_proxy 127.0.0.1:${toString config.services.headplane.settings.server.port}
            }
            handle {
              reverse_proxy ${headscale.address}:${toString headscale.port}
            }
          '';
        };

        # The server joins its own tailnet with a short-lived key minted locally, so it needs
        # no stored secret. It talks to Headscale directly, so it does not depend on TLS.
        systemd.services.headscale-local-authkey = {
          description = "Mint a Headscale preauth key for this host";
          after = ["headscale.service"];
          requires = ["headscale.service"];
          before = ["tailscaled-autoconnect.service"];
          requiredBy = ["tailscaled-autoconnect.service"];
          path = [headscale.package pkgs.jq];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            RuntimeDirectory = baseNameOf authKeyDir;
            RuntimeDirectoryMode = "0700";
            RuntimeDirectoryPreserve = true;
          };
          script = ''
            for _ in $(seq 30); do
              headscale users list >/dev/null 2>&1 && break
              sleep 1
            done
            userId() {
              headscale users list -o json \
                | jq -r --arg name ${tailnetUser} '.[] | select(.name == $name) | .id'
            }
            [ -n "$(userId)" ] || headscale users create ${tailnetUser}
            umask 077
            headscale preauthkeys create --user "$(userId)" --expiration 1h -o json \
              | jq -r .key > ${authKeyDir}/key
          '';
        };

        services.tailscale = {
          enable = true;
          openFirewall = true;
          authKeyFile = "${authKeyDir}/key";
          extraUpFlags = ["--login-server=${localUrl}"];
        };

        networking.firewall = {
          allowedTCPPorts = [80 443];
          allowedUDPPorts = [3478];
        };
      };
    };
    checks = {
      self,
      lib,
      pkgs,
      system,
      ...
    }:
      lib.optionalAttrs (system == "x86_64-linux") {
        self-join = import ./_checks/self-join.nix {inherit self pkgs;};
      };
    docs = ''
      Runs a Headscale control server for the tailnet at `https://${domain}`, with the
      Headplane web UI at `/admin` and an embedded DERP relay. Caddy obtains the TLS
      certificate. MagicDNS names hosts under `tail.iameasytoremember.com`.

      The server registers itself on its own tailnet under the `${tailnetUser}` Headscale user
      with a one-hour preauth key minted at boot, so it needs no stored key. Headplane creates
      its session cookie secret on first start and keeps it in its state directory.
    '';
    imperativeSteps = ''
      Point a DNS-only A record for `${domain}` at the host, and allow inbound TCP 80 and 443
      and UDP 3478 (STUN) and 41641 (direct WireGuard) in the cloud firewall.

      To log in to Headplane, create an API key on the host with
      `sudo headscale apikeys create --expiration 90d` and paste it on the login page.
    '';
  }
