# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "remmina";
  ids = ["remmina"];
  module = _: {
    home = {
      lib,
      pkgs,
      config,
      userName,
      ...
    }: let
      home = config.home.homeDirectory;
      # nisha keeps xrdp on loopback; RDP travels through its SSH server on port 6767.
      nishaProfile = lib.generators.toINI {} {
        remmina = {
          name = "nisha";
          group = "";
          protocol = "RDP";
          server = "localhost:3389";
          username = userName;
          resolution_mode = 2;
          scale = 2;
          colordepth = 99;
          quality = 9;
          sound = "local";
          ssh_tunnel_enabled = 1;
          ssh_tunnel_loopback = 1;
          ssh_tunnel_server = "130.61.87.165:6767";
          ssh_tunnel_username = userName;
          # 1 = public key file.
          ssh_tunnel_auth = 1;
          ssh_tunnel_privatekey = "${home}/.ssh/id_ed25519";
        };
      };
    in {
      home.packages = [pkgs.remmina];

      # Remmina rewrites profiles on connect, so install a writable copy instead of a store link.
      home.activation.remminaProfiles = lib.hm.dag.entryAfter ["writeBoundary"] ''
        run install -Dm600 ${pkgs.writeText "nisha.remmina" nishaProfile} \
          ${lib.escapeShellArg "${config.xdg.dataHome}/remmina/nisha.remmina"}
      '';
    };
  };
}
