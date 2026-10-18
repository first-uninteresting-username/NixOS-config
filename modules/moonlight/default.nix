# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "moonlight";
  ids = ["moonlight"];
  module = _: {
    home = {pkgs, ...}: {
      home.packages = with pkgs; [
        moonlight-qt
      ];
    };
  };
}
