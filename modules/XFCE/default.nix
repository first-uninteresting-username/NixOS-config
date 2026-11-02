# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "XFCE";
  ids = ["XFCE"];
  module = _: {
    nixos = {pkgs, ...}: {
      services.xserver = {
        enable = true;
        excludePackages = [pkgs.xterm];
        desktopManager.xfce.enable = true;
      };

      programs.dconf.enable = true;

      # The ssh module runs the OpenSSH agent; XFCE would add a second one.
      services.gnome.gcr-ssh-agent.enable = false;
    };
  };
}
