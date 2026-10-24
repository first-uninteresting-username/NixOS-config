# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "sunshine";
  ids = ["sunshine"];
  state = {
    nixos.directories = [
      "/var/lib/sunshine"
    ];
  };
  module = _: {
    nixos = _: {
      services.sunshine = {
        enable = true;
        autoStart = true;
        openFirewall = true;
        capSysAdmin = true;
      };

      services.udev.extraRules = ''
        KERNEL=="uinput", MODE="0660", GROUP="input", SYMLINK+="uinput"
      '';

      boot.kernelModules = ["uinput"];
    };
  };
}
