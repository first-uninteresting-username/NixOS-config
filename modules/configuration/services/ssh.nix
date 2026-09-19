# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
_: {
  flake = {
    nixosModules.ssh = {
      lib,
      config,
      ...
    }: let
      sshDir =
        if config.custom.preservation.enable
        then "/persist"
        else "";
      userKey = "${sshDir}${config.users.users.${config.custom.user.name}.home}/.ssh/id_ed25519";
      hostKey = "${sshDir}/etc/ssh/ssh_host_ed25519_key";
    in {
      programs.ssh.startAgent = true;
      systemd.tmpfiles.rules = [
        "d ${config.users.users.${config.custom.user.name}.home}/.ssh 0700 ${config.custom.user.name} users - -"
      ];
      users.users.${config.custom.user.name} = {
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPGzRUdlC8OdgeZhL9Kn+57GHAmMpkfBG3iqPl3dRYTM Desktop_key"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFb1ByQK+SH7b7ZD+Epe5zYDyOUp2V0Sr/GcAfKy8J4y Laptop_key"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPhyyqVG8KdfHL00jBin/8rJzaD1Str3lO7N+IeF8fPI Server_key"
        ];
      };

      # This is either the worst or the smartest thing in the history of humanity, nothing in between
      sops.secrets."ssh_keys/private/${config.custom.hostname}" = {
        owner = config.custom.user.name;
        inherit (config.users.users.${config.custom.user.name}) group;
        mode = "0600";
        path = userKey;
      };
      sops.secrets."ssh_keys/public/${config.custom.hostname}" = {
        owner = config.custom.user.name;
        inherit (config.users.users.${config.custom.user.name}) group;
        mode = "0644";
        path = "${userKey}.pub";
      };

      sops.secrets."host_keys/private/${config.custom.hostname}" = {
        mode = "0600";
        path = hostKey;
        restartUnits = ["sshd.service"];
      };
      sops.secrets."host_keys/public/${config.custom.hostname}" = {
        mode = "0644";
        path = "${hostKey}.pub";
      };

      services.openssh.hostKeys = [
        {
          path = hostKey;
          type = "ed25519";
        }
      ];

      preservation.preserveAt = lib.mkIf config.custom.preservation.enable {
        "/persist" = {
          directories = [
            {directory = "/etc/ssh";}
          ];
          users.${config.custom.user.name} = {
            directories = [
              {
                directory = ".ssh";
                mode = "0700";
              }
            ];
          };
        };
      };

      home-manager.users.${config.custom.user.name} = _: {
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

    nixosModules.secretless-ssh = {
      lib,
      config,
      ...
    }: let
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILh2Ni5c9wMmg1ojjGmlf0oPuijIYVQhV8kLX3nSoP4v Showcase_keys";
      privateKey = ''
        -----BEGIN OPENSSH PRIVATE KEY-----
        b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
        QyNTUxOQAAACC4djYuXPcDJoNaI4xppX9KD7ooyGFUIVfJC1950qD+LwAAAJAQ6ZXrEOmV
        6wAAAAtzc2gtZWQyNTUxOQAAACC4djYuXPcDJoNaI4xppX9KD7ooyGFUIVfJC1950qD+Lw
        AAAEDwlgVBitg7jIrkgRl7bdA7c1AuY+/JFbmIfdo+Xa8PxLh2Ni5c9wMmg1ojjGmlf0oP
        uijIYVQhV8kLX3nSoP4vAAAADVNob3djYXNlX2tleXM=
        -----END OPENSSH PRIVATE KEY-----
      '';
    in {
      programs.ssh.startAgent = true;
      systemd.tmpfiles.rules = [
        "d ${config.users.users.${config.custom.user.name}.home}/.ssh 0700 ${config.custom.user.name} users - -"
        "f ${config.users.users.${config.custom.user.name}.home}/.ssh/id_* 0600 ${config.custom.user.name} users - -"
        "f ${config.users.users.${config.custom.user.name}.home}/.ssh/*.pub 0644 ${config.custom.user.name} users - -"
        "f ${config.users.users.${config.custom.user.name}.home}/.ssh/authorized_keys 0644 ${config.custom.user.name} users - -"
      ];
      users.users.${config.custom.user.name} = {
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPGzRUdlC8OdgeZhL9Kn+57GHAmMpkfBG3iqPl3dRYTM Desktop_key"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFb1ByQK+SH7b7ZD+Epe5zYDyOUp2V0Sr/GcAfKy8J4y Laptop_key"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPhyyqVG8KdfHL00jBin/8rJzaD1Str3lO7N+IeF8fPI Server_key"
        ];
      };

      preservation.preserveAt = lib.mkIf config.custom.preservation.enable {
        "/persist" = {
          users.${config.custom.user.name} = {
            directories = [
              {
                directory = ".ssh";
                mode = "0700";
              }
            ];
          };
        };
      };

      home-manager.users.${config.custom.user.name} = {pkgs, ...}: {
        home.packages = with pkgs; [
          lazyssh
        ];
        home.file = {
          ".ssh/id_ed25519" = {
            text = privateKey;
          };
          ".ssh/id_ed25519.pub" = {
            text = publicKey;
          };
        };
        programs.ssh = {
          enable = true;
          enableDefaultConfig = false;
          settings = {
            "*" = {
              IdentityFile = "~/.ssh/id_ed25519";
              AddKeysToAgent = "yes";
            };
          };
        };
      };
    };

    nixosModules.ssh-debug = _: {
      services.openssh = {
        enable = true;
        settings = {
          PermitRootLogin = "yes";
          PasswordAuthentication = true;
        };
      };
    };
    nixosModules.ssh-server = _: let
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
