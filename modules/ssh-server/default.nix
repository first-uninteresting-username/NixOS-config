# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "ssh-server";
  ids = ["ssh-server"];
  module = _: {
    nixos = _: let
      sshPort = 6767;
    in {
      services.openssh = {
        enable = true;
        ports = [sshPort];
        settings = {
          PasswordAuthentication = false;
          PermitRootLogin = "no";
          KbdInteractiveAuthentication = false;
        };
        hostKeys = [
          {
            path = "/etc/ssh/ssh_host_ed25519_key";
            type = "ed25519";
          }
        ];
      };

      services.fail2ban = {
        enable = true;
        jails.sshd = {
          settings = {
            enabled = true;
            port = toString sshPort;
            filter = "sshd";
            maxretry = 5;
            bantime = "1h";
            findtime = "10m";
          };
        };
      };

      networking.firewall.allowedTCPPorts = [sshPort];
    };
  };
}
