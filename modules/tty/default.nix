# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "tty";
  ids = ["tty"];
  module = _: {
    nixos = {config, ...}: {
      # A very fancy terminal with mouse suppport
      services = {
        kmscon = {
          enable = true;
          config.hwaccel = config.hardware.graphics.enable;
        };
        gpm = {
          enable = true;
          protocol = "imps2";
        };
      };
    };
  };
}
