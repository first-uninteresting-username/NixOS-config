# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
# deploy-rs nodes. Deploy with `nix run github:serokell/deploy-rs -- .#<node>`.
{inputs}: let
  inherit (inputs) self nixpkgs deploy-rs;

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
  nodes = {
    nisha =
      nixosNode {
        hostName = "nisha";
        system = "aarch64-linux";
        sshPort = 6767;
      }
      // {
        hostname = "130.61.87.165";
        # The x86_64 hosts cannot build aarch64-linux, so build on the target.
        remoteBuild = true;
        interactiveSudo = true;
      };
  };
}
