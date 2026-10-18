# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  # Select this hardware fragment from hosts/<name>.nix alongside common module IDs.
  name = "host-example";
  ids = ["host-example"];
  module = _: {
    nixos = _: {
      system.stateVersion = "26.11";
      # Supply the actual hardware, disk layout, and boot loader here.
    };
  };
}
