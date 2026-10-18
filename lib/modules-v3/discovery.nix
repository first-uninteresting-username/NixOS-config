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
}: let
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
      then throw "modules-v3: host '${host.name}': role must be 'nixos' or 'home'"
      else host
  ) (lib.concatMap loadMany (files hostsDir));
  commonArgs = builtins.foldl' (
    acc: source: let
      declarations = load source;
      duplicates = builtins.attrNames (builtins.intersectAttrs acc declarations);
    in
      if duplicates != []
      then throw "modules-v3: duplicate common arguments: ${lib.concatStringsSep ", " duplicates}"
      else acc // declarations
  ) {} (files argumentsDir);
  registry = mkRegistry {inherit modules commonArgs;};
  hostSet = builtins.foldl' (acc: host:
    if builtins.hasAttr host.name acc
    then throw "modules-v3: duplicate host name '${host.name}'"
    else acc // {${host.name} = host;}) {}
  hosts;
  buildHosts = role:
    lib.mapAttrs (_: host:
      registry.mkHost (builtins.removeAttrs host ["source" "directory"]))
    (lib.filterAttrs (_: host: host.role == role) hostSet);
in
  registry
  // {
    inherit hosts;
    nixosConfigurations = buildHosts "nixos";
    homeConfigurations = buildHosts "home";
  }
