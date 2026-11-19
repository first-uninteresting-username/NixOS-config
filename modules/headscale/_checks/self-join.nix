# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
# Boot the server and verify that it joins its own tailnet and serves Headplane.
{
  self,
  pkgs,
  ...
}:
pkgs.testers.runNixOSTest {
  name = "headscale-self-join";

  nodes.machine = {lib, ...}: {
    imports = [self.nixosModules.headscale];
    # The exported module embeds the default Home Manager user.
    home-manager.users.user.home.stateVersion = "26.11";
    users.users.user.isNormalUser = true;
    virtualisation.memorySize = 2048;
    environment.systemPackages = [pkgs.jq pkgs.curl];
    # The sandbox has no internet, and Headscale exits if it cannot fetch Tailscale's DERP map.
    services.headscale.settings.derp.urls = lib.mkForce [];
  };

  testScript = ''
    # The autoconnect oneshot exits once it is up, so poll the backend state instead.
    machine.wait_until_succeeds("tailscale status --json | jq -e '.BackendState == \"Running\"'", timeout=120)
    machine.succeed("headscale nodes list -o json | jq -e 'length == 1'")

    machine.wait_for_open_port(3000)
    machine.succeed("curl -sf http://127.0.0.1:3000/admin/login >/dev/null")
    secret = machine.succeed("cat /var/lib/headplane/cookie-secret")
    assert len(secret) == 32, f"cookie secret has {len(secret)} characters"

    # A restart keeps the secret, so existing sessions stay valid.
    machine.systemctl("restart headplane.service")
    machine.wait_for_open_port(3000)
    machine.succeed(f"test \"$(cat /var/lib/headplane/cookie-secret)\" = '{secret}'")
  '';
}
