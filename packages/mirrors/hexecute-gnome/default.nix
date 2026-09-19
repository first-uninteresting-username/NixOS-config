# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
_: {
  perSystem = {inputs', ...}: {
    packages.hexecute-gnome = inputs'.hexecute-gnome.packages.default;
  };
}
