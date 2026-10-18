# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "secrets";
  ids = ["secrets"];
  module = _: {
    nixos = {
      pkgs,
      lib,
      userName,
      preservationEnable,
      inputs,
      self,
      packages,
      ...
    }: let
      preservationDir =
        if preservationEnable
        then "/persist"
        else "";
    in {
      imports = [
        inputs.sops-nix.nixosModules.sops
        # TODO: Create secrets module (same concept as preservation module)
      ];

      preservation.preserveAt = lib.mkIf preservationEnable {
        "/persist" = {
          directories = ["/var/lib/sops-nix"];
          users.${userName} = {
            directories = [".config/sops/age"];
          };
        };
      };

      environment.systemPackages = with pkgs; [
        sops
        age
        packages.sops-easy
      ];

      sops = {
        defaultSopsFile = "${self}/secrets/secrets.yaml";

        age = {
          keyFile = "${preservationDir}/var/lib/sops-nix/keys.txt";
          generateKey = false;
          sshKeyPaths = [];
        };
      };
    };
  };
  packages = {pkgs, ...}: {
    sops-easy = pkgs.writeShellApplication {
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
