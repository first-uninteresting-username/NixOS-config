# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
# A client joins a Headscale server with a reusable preauth key and reaches it over the tailnet.
{
  self,
  pkgs,
  ...
}: let
  keyFile = "/etc/tailnet-preauth-key";
  common = {
    # The exported modules embed the default Home Manager user.
    home-manager.users.user.home.stateVersion = "26.11";
    users.users.user.isNormalUser = true;
    environment.systemPackages = [pkgs.jq];
  };
in
  pkgs.testers.runNixOSTest {
    name = "tailnet-join";

    node.specialArgs = {
      loginServer = "http://server:8080";
      authKeyFile = keyFile;
      secretsEnable = false;
    };

    nodes = {
      server = {lib, ...}: {
        imports = [self.nixosModules.headscale common];
        virtualisation.memorySize = 2048;
        services.headscale = {
          address = "0.0.0.0";
          settings = {
            server_url = lib.mkForce "http://server:8080";
            # The sandbox has no internet, and Headscale exits if it cannot fetch Tailscale's DERP map.
            derp.urls = lib.mkForce [];
          };
        };
        networking.firewall.allowedTCPPorts = [8080];
      };
      client = {
        imports = [self.nixosModules.tailnet common];
        # The key arrives during the test, so autoconnect is started by hand.
        systemd.services.tailscaled-autoconnect.wantedBy = pkgs.lib.mkForce [];
      };
    };

    testScript = ''
      start_all()
      server.wait_until_succeeds("tailscale status --json | jq -e '.BackendState == \"Running\"'", timeout=120)
      user = server.succeed("headscale users list -o json | jq -r '.[] | select(.name == \"nixi\") | .id'").strip()
      key = server.succeed(f"headscale preauthkeys create --user {user} --reusable --expiration 1h -o json | jq -r .key").strip()

      client.wait_for_unit("tailscaled.service")
      client.succeed(f"install -m 600 /dev/stdin ${keyFile} <<< '{key}'")
      client.systemctl("start tailscaled-autoconnect.service")
      client.wait_until_succeeds("tailscale status --json | jq -e '.BackendState == \"Running\"'", timeout=120)

      server.wait_until_succeeds("headscale nodes list -o json | jq -e 'length == 2'")
      server_ip = server.succeed("tailscale ip -4").strip()
      client.wait_until_succeeds(f"tailscale ping --c 1 {server_ip}", timeout=60)
    '';
  }
