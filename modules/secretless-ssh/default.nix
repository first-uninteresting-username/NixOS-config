# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "secretless-ssh";
  ids = ["secretless-ssh"];
  module = _: {
    nixos = {
      lib,
      config,
      userName,
      preservationEnable,
      ...
    }: {
      programs.ssh.startAgent = true;
      systemd.tmpfiles.rules = [
        "d ${config.users.users.${userName}.home}/.ssh 0700 ${userName} users - -"
        "f ${config.users.users.${userName}.home}/.ssh/id_* 0600 ${userName} users - -"
        "f ${config.users.users.${userName}.home}/.ssh/*.pub 0644 ${userName} users - -"
        "f ${config.users.users.${userName}.home}/.ssh/authorized_keys 0644 ${userName} users - -"
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
    };
    home = {pkgs, ...}: let
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
}
