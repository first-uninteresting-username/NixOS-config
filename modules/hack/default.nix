# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "hack";
  ids = ["hack"];
  packages = {
    inputs,
    system,
    ...
  }: {default = inputs.hack.packages.${system}.default;};
}
