# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{lib, ...}: {
  # Deliberately broken fixtures are opt-in and never enter a successful CI gate.
  options.flake.regressionChecks = lib.mkOption {
    type = lib.types.lazyAttrsOf (lib.types.lazyAttrsOf lib.types.package);
    default = {};
    description = "Behavioral checks with representative intentional regressions; expect failure.";
  };
}
