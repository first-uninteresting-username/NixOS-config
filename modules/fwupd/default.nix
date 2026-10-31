# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "fwupd";
  ids = ["fwupd"];
  state = {
    nixos.directories = [
      "/var/lib/fwupd"
    ];
  };
  module = _: {
    nixos = _: {
      services.fwupd.enable = true;
    };
  };
}
