# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  self,
  inputs,
  ...
}: {
  flake = {
    nixosModules.secrets = {
      pkgs,
      lib,
      config,
      ...
    }: let
      preservationDir =
        if config.custom.preservation.enable
        then "/persist"
        else "";
    in {
      imports = [
        inputs.sops-nix.nixosModules.sops
        # TODO: Create secrets module (same concept as preservation module)
        self.nixosModules.shell-secret-programs
      ];

      preservation.preserveAt = lib.mkIf config.custom.preservation.enable {
        "/persist" = {
          directories = ["/var/lib/sops-nix"];
          users.${config.custom.user.name} = {
            directories = [".config/sops/age"];
          };
        };
      };

      environment.systemPackages = with pkgs; [
        sops
        age
        self.packages.${pkgs.stdenv.hostPlatform.system}.sops-easy
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
}
