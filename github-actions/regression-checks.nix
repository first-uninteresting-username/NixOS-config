# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  self,
  inputs,
  lib,
  withSystem,
  ...
}: {
  flake.regressionChecks.x86_64-linux = withSystem "x86_64-linux" ({pkgs, ...}: {
    persistence-without-user-state = (import ../modules/preservation/_checks/persistence.nix {inherit self inputs lib pkgs;}).regression;
    upgrade = (import ../modules/update/_checks/default.nix {inherit self inputs lib pkgs;}).regression;
  });
}
