# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
_: {
  flake = {
    nixosModules = {
      gaming-distrobox = {
        lib,
        config,
        ...
      }: {
        preservation.preserveAt = lib.mkIf config.custom.preservation.enable {
          "/persist" = {
            users.${config.custom.user.name} = {
              directories = [
                "homes"
              ];
            };
          };
        };

        home-manager.users.${config.custom.user.name} = {
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
      gaming = {
        config,
        pkgs,
        lib,
        ...
      }: {
        preservation.preserveAt = lib.mkIf config.custom.preservation.enable {
          "/persist" = {
            users.${config.custom.user.name} = {
              directories = [
                ".config/lutris"
                ".local/share/lutris"
                ".cache/lutris"
                ".local/share/PrismLauncher"
                ".config/PrismLauncher"
                ".config/heroic"
                ".local/share/heroic"
                ".config/hydra"
                ".local/share/keyrings"
                ".cache/ProtonPlus"
                ".luanti"
              ];
              files = [
                # User-level files to persist (relative to $HOME)
              ];
            };
          };
        };

        home-manager.users.${config.custom.user.name} = _: {
          home.packages = with pkgs; [
            hydralauncher
            heroic
            protonplus
            luanti
          ];
          programs = {
            lutris = {
              enable = true;
            };
            prismlauncher = {
              enable = true;
            };
          };
        };
      };
    };
  };
}
