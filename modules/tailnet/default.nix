# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "tailnet";
  ids = ["tailnet"];
  state.nixos.directories = ["/var/lib/tailscale"];
  module = {
    loginServer ? "https://headscale.iameasytoremember.com",
    authKeyFile ? "/run/secrets/HEADSCALE_PREAUTH_KEY",
  }: {
    nixos = {
      config,
      lib,
      secretsEnable,
      ...
    }: {
      config =
        {
          services.tailscale = {
            enable = true;
            openFirewall = true;
            # Read only on first login; the node key in /var/lib/tailscale is reused afterwards.
            inherit authKeyFile;
            extraUpFlags = ["--login-server=${loginServer}"];
          };
        }
        // lib.optionalAttrs secretsEnable {
          sops.secrets."HEADSCALE_PREAUTH_KEY".path = authKeyFile;
          systemd.services.tailscaled-autoconnect = lib.mkIf config.sops.useSystemdActivation {
            after = ["sops-install-secrets.service"];
            requires = ["sops-install-secrets.service"];
          };
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
      join = import ./_checks/join.nix {inherit self pkgs;};
    };
  docs = ''
    Joins the host to the self-hosted tailnet run by the `headscale` module on nisha, with
    `loginServer` as the control server. On first boot `tailscaled-autoconnect` logs in with
    the reusable preauth key that sops-nix decrypts to `authKeyFile`. The node key then lives
    in `/var/lib/tailscale`, which persists under preservation, so later boots do not need
    the preauth key.
  '';
  imperativeSteps = ''
    Mint a reusable preauth key on the Headscale server and store it in sops as
    `HEADSCALE_PREAUTH_KEY`:

    ```bash
    sudo headscale preauthkeys create --user "$(sudo headscale users list -o json \
      | jq -r '.[] | select(.name == "nixi") | .id')" --reusable --expiration 8760h
    ```

    The key only matters for new or reinstalled hosts; rotate it before it expires.
  '';
}
