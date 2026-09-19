# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
_: {
  flake = {
    nixosModules.CHANGEME = {
      lib,
      config,
      ...
    }: {
      preservation.preserveAt = lib.mkIf config.custom.preservation.enable {
        "/persist" = {
          directories =
            # Omit this block if you don't plan including any subdirectories of /var/lib
            [
              # System-level dirs to persist
            ];
          files = [
            # System-level files to persist
          ];
          users.${config.custom.user.name} = {
            directories = [
              # User-level dirs to persist (relative to $HOME)
            ];
            files = [
              # User-level files to persist (relative to $HOME)
            ];
          };
        };
      };

      # System config goes here

      home-manager.users.${config.custom.user.name} = _: {
        # Home config goes here
      };
    };
  };
}
