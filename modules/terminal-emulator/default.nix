# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "terminal-emulator";
  ids = ["terminal-emulator"];
  module = _: {
    home = _: {
      programs.ghostty.enable = true;
      stylix.targets.ghostty.enable = true;
    };
  };
}
