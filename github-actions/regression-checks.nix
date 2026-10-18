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
    networkmanager-secrets-without-reload = (import ../modules/networking-desktop/_checks/secrets.nix {inherit self inputs lib pkgs;}).regression;
    gnome-session = (import ../modules/GNOME/_checks/session.nix {inherit self inputs lib pkgs;}).regression;
    upgrade = (import ../modules/update/_checks/default.nix {inherit self inputs lib pkgs;}).regression;
    printing-discovery = (import ../modules/printing/_checks/discovery.nix {inherit self inputs lib pkgs;}).regression;
    iso-john = (import ../modules/iso/_checks/smoke.nix {inherit self pkgs;}).regressions.iso-john;
    iso-wall-e = (import ../modules/iso/_checks/smoke.nix {inherit self pkgs;}).regressions.iso-wall-e;
  });
}
