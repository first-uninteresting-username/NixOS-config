# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
# Derive CI matrices and opt-in regression outputs from the discovered registry.
{
  inputs,
  lib,
  registry,
  systems,
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

  # These are the ISO package exports in modules/host-{john,wall-e}/default.nix.
  isoPackageNamesBySystem."x86_64-linux" = ["host-john" "host-wall-e"];
  isIsoPackage = system: name:
    builtins.elem name (isoPackageNamesBySystem.${system} or []);
  filterPackages = predicate:
    lib.mapAttrs (
      system: packages:
        lib.filterAttrs (name: _: predicate system name) packages
    )
    registry.packages;

  hostsBySystem = lib.foldl' (
    bySystem: hostName: let
      host = registry.nixosConfigurations.${hostName};
      system = host.pkgs.stdenv.hostPlatform.system;
    in
      lib.recursiveUpdate bySystem {
        ${system}.${hostName} = host.config.system.build.toplevel;
      }
  ) {} (builtins.attrNames registry.nixosConfigurations);
in {
  hosts = hostsBySystem;

  githubActions = let
    tests = mkMatrix "checks" (
      lib.mapAttrs (_: lib.filterAttrs (name: _: !lib.hasPrefix "iso-" name))
      registry.checks
    );
    isoTests = mkMatrix "checks" (
      lib.mapAttrs (_: lib.filterAttrs (name: _: lib.hasPrefix "iso-" name))
      registry.checks
    );
    packages = mkMatrix "packages" (filterPackages (system: name: !isIsoPackage system name));
    isos = mkMatrix "packages" (filterPackages isIsoPackage);
    hosts = mkMatrix "hosts" hostsBySystem;
    ownership = lib.genAttrs systems (system:
      registry.ownership {
        root = inputs.self;
        inherit system;
        pkgs = inputs.nixpkgs.legacyPackages.${system};
      });
  in {
    inherit tests packages hosts isos isoTests;
    selection = {inherit ownership tests packages isos isoTests;};
    # Preserve the old check matrix name for local consumers.
    checks = tests;
    fullMatrix.include =
      packages.include ++ tests.include ++ hosts.include ++ isos.include ++ isoTests.include;
  };

  regressionChecks = import ./regression-checks.nix {inherit inputs lib;};
}
