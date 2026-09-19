# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  config,
  inputs,
  lib,
  ...
}: let
  runners = {
    "x86_64-linux" = "ubuntu-latest";
    "aarch64-linux" = "ubuntu-26.04-arm";
  };

  mkMatrix = attrPrefix: targets: let
    rawMatrix =
      (inputs.nix-github-actions.lib.mkGithubMatrix {
        checks = targets;
        inherit attrPrefix;
        platforms = runners;
      }).matrix;
  in {
    include = map (entry: entry // {type = attrPrefix;}) rawMatrix.include;
  };

  hostsBySystem = lib.foldl' (
    bySystem: hostName: let
      host = config.flake.nixosConfigurations.${hostName};
      system = host.pkgs.stdenv.hostPlatform.system;
    in
      bySystem
      // {
        ${system}.${hostName} = host.config.system.build.toplevel;
      }
  ) {} (builtins.attrNames config.flake.nixosConfigurations);
in {
  flake = {
    hosts = hostsBySystem;

    githubActions = let
      checks = mkMatrix "checks" config.flake.checks;
      packages = mkMatrix "packages" config.flake.packages;
      hosts = mkMatrix "hosts" hostsBySystem;
    in {
      inherit checks packages hosts;

      fullMatrix.include = checks.include ++ packages.include ++ hosts.include;
    };
  };
}
