# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  self,
  pkgs,
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
      isoImage = self.nixosConfigurations.${hostName}.config.system.build.isoImage;
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
  checks = mkChecks pkgs false;
  regressions = mkChecks pkgs true;
}
