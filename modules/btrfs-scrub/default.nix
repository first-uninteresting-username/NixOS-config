# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "btrfs-scrub";
  ids = ["btrfs-scrub"];
  module = _: {
    nixos = _: {
      services.btrfs.autoScrub = {
        enable = true;
        interval = "monthly";
        # Scrub covers the whole filesystem, and / is tmpfs, so one subvolume mount is enough.
        fileSystems = ["/persist"];
      };
    };
  };
}
