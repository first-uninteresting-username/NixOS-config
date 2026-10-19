# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "jail";
  ids = ["jail"];
  checks = {
    self,
    pkgs,
    lib,
    system,
    ...
  }:
    lib.optionalAttrs (system == "x86_64-linux") {
      default = import ./_checks/runtime.nix {inherit self pkgs;};
    };
}
