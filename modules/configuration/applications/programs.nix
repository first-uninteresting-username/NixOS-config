# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
_: {
  flake = {
    nixosModules.programs-desktop = {
      lib,
      config,
      pkgs,
      ...
    }: {
      preservation.preserveAt = lib.mkIf config.custom.preservation.enable {
        "/persist" = {
          directories = [
            "/var/lib/kdeconnect"
          ];
          files = [
            # System-level files to persist
          ];
          users.${config.custom.user.name} = {
            directories = [
              ".config/kdeconnect"
            ];
            files = [
              # User-level files to persist (relative to $HOME)
            ];
          };
        };
      };

      programs = {
        kdeconnect.enable = true;
      };

      # Probably not the right place for that
      services.ananicy = {
        # Temporary
        enable = false;
        package = pkgs.ananicy-cpp;
        rulesProvider = pkgs.ananicy-rules-cachyos;
      };

      home-manager.users.${config.custom.user.name} = _: {
      };
    };
  };
}
