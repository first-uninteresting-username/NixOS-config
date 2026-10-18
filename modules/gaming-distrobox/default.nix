# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "gaming-distrobox";
  ids = ["gaming-distrobox"];
  module = _: {
    nixos = {
      lib,
      userName,
      preservationEnable,
      ...
    }: {
      preservation.preserveAt = lib.mkIf preservationEnable {
        "/persist" = {
          users.${userName} = {
            directories = [
              "homes"
            ];
          };
        };
      };
    };
    home = {
      config,
      lib,
      ...
    }: {
      home.activation.createGboxDir = lib.hm.dag.entryAfter ["writeBoundary"] ''
        mkdir -p "${config.home.homeDirectory}/homes/Gbox"
      '';

      programs.distrobox = {
        enable = true;
        containers = {
          Gbox = {
            image = "ghcr.io/first-uninteresting-username/gbox-gnome-amd:20260816";
            init = false;
            root = false;
            start_now = false;
            exported_apps = "steam lutris protonup-qt prismlauncher";
            # Likely doesn't work, because I created it
            init_hooks = "/usr/local/bin/prism-instance-bootstrap.sh";
            home = "${config.home.homeDirectory}/homes/Gbox";
          };
        };
      };
    };
  };
}
