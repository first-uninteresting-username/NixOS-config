# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
_: {
  imports = [../common/desktop-modules.nix];

  custom = {
    stylix = {
      image = {
        width = "2560";
        height = "1440";
      };
    };
  };
}
