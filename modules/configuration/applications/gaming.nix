# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{inputs, ...}: {
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
        imports = [
          inputs.nix-crab.nixosModules.default
        ];

        programs.nix-crab = {
          slssteam.enable = true;
          # LuaTools stack: use the slsteam-moon fork (Lua manifest importer)
          # for downloads from the Steam CDN; takes precedence over slssteam
          slssteam-moon.enable = true;
          cloudredirect.enable = true;
          cloudredirect.moon.enable = true;
        };

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
                ".local/share/keyrings"
                ".cache/ProtonPlus"
                ".luanti"
                # nix-crab / host Steam stack (~/.steam is a compat symlink
                # to .local/share/Steam created by programs.steam itself)
                ".local/share/Steam"
                ".config/SLSsteam"
                ".config/CloudRedirect"
                ".local/share/Lumen"
              ];
              files = [
                # User-level files to persist (relative to $HOME)
              ];
            };
          };
        };

        home-manager.users.${config.custom.user.name} = _: {
          imports = [
            inputs.nix-crab.homeModules.default
          ];

          home.packages = with pkgs; [
            heroic
            protonplus
            luanti
          ];
          programs = {
            nix-crab = {
              luatools = {
                enable = true;
                # Run Lumen as a systemd user service instead of shadowing
                # the steam command with a wrapper sidecar
                lumenService = true;
              };
              cloudredirect.moon.enable = true;
            };
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
