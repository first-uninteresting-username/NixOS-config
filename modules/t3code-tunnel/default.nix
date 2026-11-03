# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "t3code-tunnel";
  ids = ["t3code" "t3code-tunnel"];
  module = _: {
    nixos = {
      config,
      lib,
      pkgs,
      secretsEnable,
      ...
    }:
      lib.optionalAttrs secretsEnable {
        sops.secrets."cloudflared_t3code_token" = {};

        # A remotely managed tunnel: Cloudflare holds the hostname and ingress rules, and the
        # setup package writes them. The host only needs the tunnel token.
        systemd.services.cloudflared-t3code = {
          description = "Cloudflare Tunnel for T3 Code";
          after = ["network-online.target"];
          wants = ["network-online.target"];
          wantedBy = ["multi-user.target"];
          serviceConfig = {
            ExecStart = lib.concatStringsSep " " [
              (lib.getExe pkgs.cloudflared)
              "tunnel --no-autoupdate run --token-file %d/token"
            ];
            LoadCredential = "token:${config.sops.secrets."cloudflared_t3code_token".path}";
            DynamicUser = true;
            Restart = "on-failure";
            RestartSec = 5;
          };
        };
      };
  };
  packages = {pkgs, ...}: {
    # Creates the tunnel, its Access gate, and DNS record, then stores the tunnel token in sops.
    setup = pkgs.writeShellApplication {
      name = "t3code-tunnel-setup";
      runtimeInputs = with pkgs; [curl jq];
      text = builtins.readFile ./_setup.sh;
    };
  };
  docs = ''
    Publishes the T3 Code server through a remotely managed Cloudflare Tunnel. The
    `cloudflared-t3code` system service reads the `cloudflared_t3code_token` sops secret, so
    the module needs `secretsEnable = true`. Cloudflare Access restricts the hostname to one
    email address in front of T3 Code's own pairing.
  '';
  imperativeSteps = ''
    Create a Cloudflare API token with Account › Cloudflare Tunnel › Edit, Account › Access:
    Apps and Policies › Edit, Zone › Zone › Read, and Zone › DNS › Edit. Then run the setup
    from the repository root on a machine that can decrypt the secrets:

    ```bash
    nix run .#t3code-tunnel-setup -- t3.example.com nisha
    ```

    It asks for the API token and the email address Access allows, creates or reuses the
    tunnel, and writes the tunnel token to `secrets/secrets.yaml` through `sudo sops-easy`.
    Commit the secret and deploy the host. The API token is not stored; revoke it afterwards.
  '';
}
