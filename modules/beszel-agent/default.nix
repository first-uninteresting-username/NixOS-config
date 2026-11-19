# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
# Beszel monitoring agent that reports to the self-hosted hub on Orchard. The agent dials out to
# the hub over WebSocket with the hub's universal token (sops `BESZEL_AGENT_TOKEN`), so it needs no
# open port and registers itself under the host name. Requires `secretsEnable`.
{mkModule, ...}:
mkModule {
  name = "beszel-agent";
  ids = ["beszel-agent"];
  module = {
    beszelHubUrl ? "https://beszel.iameasytoremember.com",
    beszelHubKey ? "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIITMRPbMnPz1+nFGnGllybpDX3kQIpf8BWaSLr12tkSQ",
  }: {
    nixos = {
      config,
      secretsEnable,
      ...
    }: {
      assertions = [
        {
          assertion = secretsEnable;
          message = "beszel-agent needs secretsEnable for the BESZEL_AGENT_TOKEN sops secret.";
        }
      ];

      sops = {
        secrets."BESZEL_AGENT_TOKEN" = {};
        templates."beszel-agent.env".content = ''
          TOKEN=${config.sops.placeholder."BESZEL_AGENT_TOKEN"}
        '';
      };

      services.beszel.agent = {
        enable = true;
        environment = {
          HUB_URL = beszelHubUrl;
          KEY = beszelHubKey;
        };
        environmentFile = config.sops.templates."beszel-agent.env".path;
      };
    };
  };
}
