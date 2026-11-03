# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
# deploy-rs nodes and a `rebuild-<node>` app for each. Deploy with `nix run config#rebuild-<node>`.
{
  lib,
  inputs,
  systems,
}: let
  inherit (inputs) self;
  inherit (inputs) nixpkgs deploy-rs;

  # Use the cached deploy-rs from nixpkgs instead of building the flake's own copy.
  deployLib = system:
    (import nixpkgs {
      inherit system;
      overlays = [
        deploy-rs.overlays.default
        (_: prev: {
          deploy-rs = {
            inherit (nixpkgs.legacyPackages.${system}) deploy-rs;
            inherit (prev.deploy-rs) lib;
          };
        })
      ];
    }).deploy-rs.lib;

  nixosNode = {
    hostName,
    system,
    sshPort ? 22,
  }: {
    hostname = hostName;
    sshUser = "nixi";
    user = "root";
    sshOpts = ["-p" (toString sshPort)];
    profiles.system.path = (deployLib system).activate.nixos self.nixosConfigurations.${hostName};
  };
in {
  deploy.nodes = {
    nisha =
      nixosNode {
        hostName = "nisha";
        system = "aarch64-linux";
        sshPort = 6767;
      }
      // {
        hostname = "130.61.117.91";
        # The x86_64 hosts cannot build aarch64-linux, so build on the target.
        remoteBuild = true;
        interactiveSudo = true;
      };
  };

  apps = lib.genAttrs systems (system: let
    pkgs = nixpkgs.legacyPackages.${system};
  in
    lib.mapAttrs' (name: _:
      lib.nameValuePair "rebuild-${name}" {
        type = "app";
        program = lib.getExe (pkgs.writeShellApplication {
          name = "rebuild-${name}";
          runtimeInputs = [pkgs.deploy-rs];
          # Extra arguments go to deploy-rs, for example `--dry-activate`.
          text = ''
            deploy ${lib.escapeShellArg "${self}#${name}"} "$@"
          '';
        });
        meta.description = "Build ${name} on the target and activate it with deploy-rs";
      })
    self.deploy.nodes);
}
