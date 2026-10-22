# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "secrets";
  ids = ["secrets"];
  docs = ''
    Sops-nix decrypts the host's encrypted secrets with an age identity supplied during installation.
    Set `secretsEnable = true` to enable decryption and credential consumers.
    With it disabled, selected modules retain their ordinary functionality without managed credentials.
    The `sops-easy` command selects the installed identity when editing encrypted files.
    Keep secret values and private keys out of the repository and generated documentation.
  '';
  imperativeSteps = {
    role,
    secretsEnable,
    preservationEnable,
  }:
    if role != "nixos" || !secretsEnable
    then null
    else let
      keyDirectory = "${
        if preservationEnable
        then "/persist"
        else ""
      }/var/lib/sops-nix";
    in ''
      Before installing, seed the host's existing age identity at `${keyDirectory}/keys.txt`
      on the target. The configuration does not generate this identity.

      For an installation using nixos-anywhere's `--extra-files ./tmp`, put the key at
      `./tmp${keyDirectory}/keys.txt` on the source machine. Set the staged directory to
      mode `0700` and the key to mode `0600`, both owned by root, before installation.
      Transfer the key securely and keep it outside Git.
    '';
  module = _: {
    nixos = {
      pkgs,
      lib,
      userName,
      preservationEnable,
      secretsEnable,
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
      ];

      config = lib.mkIf secretsEnable {
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
  };
  checks = {
    self,
    inputs,
    lib,
    pkgs,
    system,
    ...
  }: {
    toggle = import ./_checks/toggle.nix {inherit self inputs lib pkgs system;};
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
