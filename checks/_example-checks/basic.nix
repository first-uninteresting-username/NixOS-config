# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
_: {
  perSystem = {pkgs, ...}: let
    checkname = "CHANGEME";
  in {
    checks.${checkname} = pkgs.testers.runNixOSTest {
      name = checkname;

      # Gh actions aarch64 runners don't have kvm
      requiredFeatures.kvm = pkgs.stdenv.hostPlatform.isx86_64;

      nodes.machine = _: {
        # VM config goes here
      };

      testScript = ''
        # Python test script
        # https://nixos.org/manual/nixos/unstable/#ssec-machine-objects - docs
      '';
    };
  };
}
