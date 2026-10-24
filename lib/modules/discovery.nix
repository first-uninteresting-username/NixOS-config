# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  lib,
  mkModule,
  mkRegistry,
  inputs,
  self,
}: {
  modulesDir,
  hostsDir,
  argumentsDir,
  systems ? [],
}: let
  # Sorted traversal skips companion sources and intentionally invalid fixture trees.
  files = directory:
    lib.concatMap (
      name: let
        path = directory + "/${name}";
        kind = (builtins.readDir directory).${name};
      in
        if lib.hasPrefix "_" name
        then []
        else if kind == "directory"
        then files path
        else lib.optional (kind == "regular" && lib.hasSuffix ".nix" name) path
    ) (builtins.attrNames (builtins.readDir directory));
  # Discovery supplies constructors and flake context, never arbitrary host arguments.
  load = source: let
    value = import source;
    context = {inherit lib mkModule inputs self;};
  in
    if builtins.isFunction value
    then value (builtins.intersectAttrs (builtins.functionArgs value) context)
    else value;
  loadMany = source: let
    value = load source;
  in
    map (declaration:
      declaration
      // {
        inherit source;
        directory = builtins.dirOf source;
      }) (
      if builtins.isList value
      then value
      else [value]
    );
  modules = lib.concatMap loadMany (files modulesDir);
  hosts = map (
    host:
      if !(builtins.elem host.role ["nixos" "home"])
      then throw "modules: host '${host.name}': role must be 'nixos' or 'home'"
      else host
  ) (lib.concatMap loadMany (files hostsDir));
  commonArgs = builtins.foldl' (
    acc: source: let
      declarations = load source;
      duplicates = builtins.attrNames (builtins.intersectAttrs acc declarations);
    in
      if duplicates != []
      then throw "modules: duplicate common arguments: ${lib.concatStringsSep ", " duplicates}"
      else acc // declarations
  ) {} (files argumentsDir);
  registry = mkRegistry {inherit modules commonArgs;};
  hostSet = builtins.foldl' (acc: host:
    if builtins.hasAttr host.name acc
    then throw "modules: duplicate host name '${host.name}'"
    else acc // {${host.name} = host;}) {}
  hosts;
  # Host files are specifications; construct them here after binding the full registry.
  buildHosts = role:
    lib.mapAttrs (_: host:
      registry.mkHost (builtins.removeAttrs host ["source" "directory"]))
    (lib.filterAttrs (_: host: host.role == role) hostSet);
  # Flake exports use each system's default Nixpkgs, independent of host selection.
  exports = lib.genAttrs systems (system:
    registry.perSystem {
      inherit system;
      pkgs = inputs.nixpkgs.legacyPackages.${system};
    });
in
  registry
  // {
    inherit hosts;
    nixosConfigurations = buildHosts "nixos";
    homeConfigurations = buildHosts "home";
    packages = lib.mapAttrs (_: outputs: outputs.packages) exports;
    checks = lib.mapAttrs (_: outputs: outputs.checks) exports;
  }
