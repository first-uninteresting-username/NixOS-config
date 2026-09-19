# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
_: {
  flake = {
    nixosModules.input = {
      pkgs,
      config,
      ...
    }: {
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
      home-manager.users.${config.custom.user.name} = _: {
        home.keyboard = {
          layout = "pl";
          variant = "";
          options = ["caps:escape"];
        };
      };
    };
  };
}
