# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
_: let
  modulename = "CHANGEME";
in {
  flake = {
    nixosModules.${modulename} = _: {
      options.custom.${modulename} = {
        # Create options here
        # Each option should have:
        # - type
        # - default
        # - example
        # - description
      };

      config = {
        # Add config here
      };
    };
  };
}
