# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "hostname";
  ids = ["hostname"];
  module = _: {
    nixos = {hostName, ...}: {
      config = {
        networking.hostName = hostName;
      };
    };
  };
}
