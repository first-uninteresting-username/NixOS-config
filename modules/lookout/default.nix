# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "lookout";
  ids = ["lookout"];
  module = _: {
    home = {pkgs, ...}: {
      home.packages = [pkgs.lookout];
    };
  };
  docs = ''
    Installs Hack Club Lookout from nixpkgs, a time-tracking client that records
    periodic screen captures. The `lookout` host ID enables it; victim and armin select it.
    The desktop launcher starts `lookout-desktop`.
    Configuration and data under `~/.config` and `~/.local/share` persist through the xdg module.
  '';
  imperativeSteps = ''
    Open Lookout and sign in to your Hack Club account on first launch.
  '';
}
