# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
# Boot the exported installation images and exercise their configured shell.
{
  self,
  pkgs,
  ...
}: let
  mkCheck = pkgs: hostName:
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
      bootTimeout = "600";
    }
    ''
      mkdir -p "$out"
      python ${./_smoke.py}
    '';
in {
  checks = {
    iso-john = mkCheck pkgs "john";
    iso-wall-e = mkCheck pkgs "wall-e";
  };
}
