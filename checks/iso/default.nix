# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  self,
  withSystem,
  ...
}: let
  mkCheck = pkgs: hostName: broken:
    pkgs.runCommand "iso-${hostName}"
    {
      nativeBuildInputs = [
        pkgs.python3
        pkgs.qemu_test
        pkgs.openssh
        pkgs.sshpass
      ];
      requiredSystemFeatures = ["kvm"];
      isoImage = self.packages.x86_64-linux.${hostName};
      inherit hostName;
      breakImage =
        if broken
        then "1"
        else "0";
      # A broken boot image should fail promptly instead of using the boot timeout.
      bootTimeout =
        if broken
        then "45"
        else "600";
    }
    ''
      mkdir -p "$out"
      python ${./_smoke.py}
    '';

  mkChecks = pkgs: broken: {
    iso-john = mkCheck pkgs "john" broken;
    iso-wall-e = mkCheck pkgs "wall-e" broken;
  };
in {
  perSystem = {
    pkgs,
    lib,
    system,
    ...
  }: {
    checks = lib.optionalAttrs (system == "x86_64-linux") (mkChecks pkgs false);
  };

  flake.regressionChecks.x86_64-linux =
    withSystem "x86_64-linux" ({pkgs, ...}: mkChecks pkgs true);
}
