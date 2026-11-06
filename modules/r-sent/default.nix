# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "r-sent";
  ids = ["r-sent"];
  module = _: {
    home = {packages, ...}: {
      home.packages = [packages.default];
    };
  };
  packages = {
    inputs,
    system,
    ...
  }: {default = inputs.r-sent.packages.${system}.default;};
}
