# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
_: {
  perSystem = {pkgs, ...}: {
    packages.sops-easy = pkgs.writeShellApplication {
      name = "sops-easy";
      runtimeInputs = with pkgs; [
        sops
      ];
      text = ''
        set -euo pipefail

        if [ -f /persist/var/lib/sops-nix/keys.txt ]; then
          KEY=/persist/var/lib/sops-nix/keys.txt
        else
          KEY=/var/lib/sops-nix/keys.txt
        fi

        export SOPS_AGE_KEY_FILE=$KEY
        export SOPS_AGE_KEY

        sops "$@"
      '';
    };
  };
}
