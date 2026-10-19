# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "ssh";
  ids = ["ssh"];
  module = _: {
    nixos = {
      lib,
      config,
      userName,
      preservationEnable,
      secretsEnable,
      hostName,
      ...
    }: let
      sshDir =
        if preservationEnable
        then "/persist"
        else "";
      userKey = "${sshDir}${config.users.users.${userName}.home}/.ssh/id_ed25519";
      hostKey = "${sshDir}/etc/ssh/ssh_host_ed25519_key";
    in
      {
        programs.ssh.startAgent = true;
        systemd.tmpfiles.rules = [
          "d ${config.users.users.${userName}.home}/.ssh 0700 ${userName} users - -"
        ];
        users.users.${userName} = {
          openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPGzRUdlC8OdgeZhL9Kn+57GHAmMpkfBG3iqPl3dRYTM Desktop_key"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFb1ByQK+SH7b7ZD+Epe5zYDyOUp2V0Sr/GcAfKy8J4y Laptop_key"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPhyyqVG8KdfHL00jBin/8rJzaD1Str3lO7N+IeF8fPI Server_key"
          ];
        };

        preservation.preserveAt = lib.mkIf preservationEnable {
          "/persist" = {
            directories = [
              {directory = "/etc/ssh";}
            ];
            users.${userName} = {
              directories = [
                {
                  directory = ".ssh";
                  mode = "0700";
                }
              ];
            };
          };
        };
      }
      // lib.optionalAttrs secretsEnable {
        sops.secrets."ssh_keys/private/${hostName}" = {
          owner = userName;
          inherit (config.users.users.${userName}) group;
          mode = "0600";
          path = userKey;
        };
        sops.secrets."ssh_keys/public/${hostName}" = {
          owner = userName;
          inherit (config.users.users.${userName}) group;
          mode = "0644";
          path = "${userKey}.pub";
        };

        sops.secrets."host_keys/private/${hostName}" = {
          mode = "0600";
          path = hostKey;
          restartUnits = ["sshd.service"];
        };
        sops.secrets."host_keys/public/${hostName}" = {
          mode = "0644";
          path = "${hostKey}.pub";
        };

        services.openssh.hostKeys = [
          {
            path = hostKey;
            type = "ed25519";
          }
        ];
      };
    home = _: {
      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;
        settings = {
          "*" = {
            IdentityFile = "~/.ssh/id_ed25519";
            AddKeysToAgent = "yes";
            IdentitiesOnly = "yes";
            ServerAliveInterval = "60";
            ServerAliveCountMax = "3";
            ConnectTimeout = "10";

            ForwardX11 = "no";
            ForwardX11Trusted = "no";
            PasswordAuthentication = "yes";
            VisualHostKey = "yes";
          };
        };
      };
    };
  };
}
