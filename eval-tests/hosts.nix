# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
let
  desktopTests = host: expected: {
    "${host}-gnome" = {
      inherit host expected;
      option = ["services" "desktopManager" "gnome" "enable"];
    };
    "${host}-gdm" = {
      inherit host expected;
      option = ["services" "displayManager" "gdm" "enable"];
    };
  };
in
  desktopTests "armin" true
  // desktopTests "victim" true
  // desktopTests "john" true
  // desktopTests "wall-e" false
