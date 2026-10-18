# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "input";
  ids = ["input"];
  module = _: {
    nixos = {pkgs, ...}: {
      console = {
        useXkbConfig = true;
      };
      environment.variables = {
        XKB_DEFAULT_LAYOUT = "pl";
        XKB_DEFAULT_VARIANT = "";
        XKB_DEFAULT_OPTIONS = "caps:escape";
      };
      services.xserver.xkb = {
        layout = "pl";
        variant = "";
      };
      services.libinput = {
        enable = true;

        touchpad = {
          naturalScrolling = true;
          tapping = true;
          disableWhileTyping = true;
          clickMethod = "clickfinger";
          accelSpeed = "0.4";
        };
        mouse = {
          accelProfile = "flat";
          middleEmulation = true;
          naturalScrolling = true;
        };
      };
      hardware.steam-hardware.enable = true;
      services.udev.packages = [pkgs.game-devices-udev-rules];
    };
    home = _: {
      home.keyboard = {
        layout = "pl";
        variant = "";
        options = ["caps:escape"];
      };
    };
  };
}
