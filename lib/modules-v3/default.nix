# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  inputs,
  self ? {},
  lib ? inputs.nixpkgs.lib,
}: let
  arguments = import ./arguments.nix {inherit lib;};
  fail = message: throw "modules-v3: ${message}";
  unique = kind: entries:
    builtins.foldl' (acc: entry:
      if builtins.hasAttr entry.name acc
      then fail "duplicate ${kind} name '${entry.name}'"
      else acc // {${entry.name} = entry.value;}) {}
    entries;
  validName = name: builtins.isString name && builtins.match "[a-zA-Z0-9][a-zA-Z0-9_-]*" name != null;
  idsValid = ids: builtins.isList ids && builtins.all builtins.isString ids;
  contextNames = ["config" "options" "lib" "pkgs" "inputs" "self" "system" "packages" "osConfig" "modulesPath" "specialArgs"];
  hostRequests = fn: builtins.filter (name: !(builtins.elem name contextNames)) (arguments.requests fn);
  applicable = role: body: role == "nixos" || body ? home || !(body ? nixos);
  sectionNames = role: body:
    builtins.filter (name: builtins.hasAttr name body)
    (
      if role == "nixos"
      then ["nixos" "home"]
      else ["home"]
    );
  selected = ids: declaration: builtins.all (id: builtins.elem id ids) declaration.ids;
  exportName = moduleName: name:
    if name == "default"
    then moduleName
    else "${moduleName}-${name}";
in rec {
  mkModule = {
    name,
    ids ? [],
    module ? (_: {}),
    packages ? {},
    checks ? {},
    assertions ? (_: []),
    docs ? null,
    imperativeSteps ? null,
  }:
    if !(validName name)
    then fail "invalid module name"
    else if !(idsValid ids)
    then fail "module '${name}': ids must be a list of strings"
    else if !(builtins.isFunction module && builtins.isFunction assertions)
    then fail "module '${name}': module and assertions must be functions"
    else {
      inherit name ids module packages checks assertions docs imperativeSteps;
    };

  mkRegistry = {
    modules ? [],
    commonArgs ? {},
  }: let
    declarations = unique "module" (map (declaration: {
        inherit (declaration) name;
        value = declaration;
      })
      modules);
    ordered = builtins.attrValues declarations;
    validatedCommonArgs = lib.mapAttrs (name: declaration:
      if builtins.elem name contextNames
      then fail "common argument '${name}' is reserved"
      else if !(declaration ? type && declaration ? description)
      then fail "common argument '${name}' needs a type and description"
      else if declaration ? default
      then declaration // {default = arguments.validate commonArgs "common declaration" name declaration.default;}
      else declaration)
    commonArgs;
    baseContext = {inherit inputs self lib;};
    labelFor = hostName: declaration: "host '${hostName}', module '${declaration.name}'";
    call = label: values: context: fallback: fn:
      arguments.bind {
        inherit fn values context fallback label;
        commonArgs = validatedCommonArgs;
      };
    packageSet = system: pkgs: declaration: let
      context = baseContext // {inherit system pkgs;};
      bound = call "module '${declaration.name}' packages" {} context {} declaration.packages;
      definitions =
        if builtins.isFunction declaration.packages
        then builtins.seq bound.required bound.value
        else declaration.packages;
    in
      definitions;
    integration = values: hostName: {config, ...} @ context: let
      user =
        call "host '${hostName}', Home Manager integration" values context config._module.args
        ({userName}: userName);
    in {
      imports = [inputs.home-manager.nixosModules.home-manager];
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        users.${user.value} = {};
      };
    };
    compile = role: values: hostName: declaration: {
      config,
      pkgs,
      ...
    } @ context: let
      label = labelFor hostName declaration;
      outer =
        call label values
        (baseContext
          // context
          // {
            inherit pkgs;
            system = pkgs.stdenv.hostPlatform.system;
          })
        (context // config._module.args)
        declaration.module;
      body = outer.value;
      active = applicable role body;
      ownPackages = packageSet pkgs.stdenv.hostPlatform.system pkgs declaration;
      sectionContext =
        baseContext
        // context
        // {
          packages = ownPackages;
          system = pkgs.stdenv.hostPlatform.system;
        };
      section = name: sectionArgs: let
        bound =
          call label values (sectionContext // sectionArgs)
          sectionArgs.config._module.args
          body.${name};
      in {
        imports = [bound.value];
        assertions = [
          {
            assertion = outer.required && bound.required;
            message = "${label}: argument validation";
          }
        ];
      };
      assertions = call label values sectionContext config._module.args declaration.assertions;
      shared = {
        assertions =
          builtins.seq outer.required (builtins.seq assertions.required
            (map (entry: entry // {message = "${label}: ${entry.message}";}) assertions.value));
      };
      user = (call label values context config._module.args ({userName}: userName)).value;
    in
      if !active
      then {}
      else {
        imports =
          [shared]
          ++ (
            if role == "nixos"
            then [(integration values hostName)]
            else []
          )
          ++ (
            if body ? ${role}
            then [(section role context)]
            else []
          )
          ++ lib.optional (role == "nixos" && body ? home) {
            home-manager.users.${user} = {
              config,
              pkgs,
              ...
            } @ homeContext:
              section "home" (homeContext // {inherit config pkgs;});
          };
      };
    namedModules = role: lib.mapAttrs (_: compile role {} "<direct consumer>") declarations;
    makeHost = {
      name,
      role,
      system,
      ids ? [],
      args ? {},
    }: let
      valid =
        if !(validName name)
        then fail "invalid host name"
        else if !(builtins.elem role ["nixos" "home"])
        then fail "host '${name}': role must be 'nixos' or 'home'"
        else if !(builtins.isString system)
        then fail "host '${name}': system must be a string"
        else if !(idsValid ids)
        then fail "host '${name}': ids must be a list of strings"
        else if args ? hostName
        then fail "host '${name}': hostName is derived, not an explicit argument"
        else true;
      values = args // {hostName = name;};
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      context = baseContext // {inherit pkgs system;};
      chosen = builtins.filter (selected ids) ordered;
      bodyFor = declaration: (call (labelFor name declaration) values context {} declaration.module).value;
      requested = targetRole: declaration: let
        body = bodyFor declaration;
      in
        lib.optionals (applicable targetRole body)
        (hostRequests declaration.module
          ++ hostRequests declaration.assertions
          ++ lib.concatMap (section: hostRequests body.${section}) (sectionNames targetRole body));
      known = lib.unique (["userName"]
        ++ builtins.attrNames validatedCommonArgs
        ++ lib.concatMap (requested "nixos") ordered);
      used =
        lib.unique (lib.optionals (role == "nixos") ["userName"]
          ++ lib.concatMap (requested role) chosen);
      unknown = builtins.filter (arg: !(builtins.elem arg known)) (builtins.attrNames args);
      unused = builtins.filter (arg: !(builtins.elem arg used)) (builtins.attrNames args);
      checked =
        if unknown != []
        then fail "host '${name}': unknown arguments: ${lib.concatStringsSep ", " unknown}"
        else lib.warnIf (unused != []) "modules-v3: host '${name}': unused arguments: ${lib.concatStringsSep ", " unused}" true;
      compiled = map (compile role values name) chosen;
      result =
        if role == "nixos"
        then
          inputs.nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [(integration values name)] ++ compiled;
          }
        else
          inputs.home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            modules = compiled;
          };
      failures =
        builtins.filter (entry: !entry.assertion)
        (result.config.assertions
          ++ lib.optionals (role == "nixos")
          (lib.concatMap (home: home.assertions) (builtins.attrValues result.config.home-manager.users)));
      oneUser = role != "nixos" || builtins.length (builtins.attrNames result.config.home-manager.users) == 1;
    in
      builtins.seq valid (builtins.seq checked (
        if !oneUser
        then fail "host '${name}': expected exactly one Home Manager user"
        else if failures != []
        then fail "host '${name}': failed assertions:\n${lib.concatMapStringsSep "\n" (entry: entry.message) failures}"
        else result
      ));
    collect = kind: system: pkgs: let
      entries = lib.concatMap (declaration: let
        packages = packageSet system pkgs declaration;
        boundChecks = call "module '${declaration.name}' checks" {} (baseContext
          // {
            inherit system pkgs packages;
            mkHost = makeHost;
          }) {}
        declaration.checks;
        definitions =
          if kind == "package"
          then packages
          else if builtins.isFunction declaration.checks
          then builtins.seq boundChecks.required boundChecks.value
          else declaration.checks;
      in
        lib.mapAttrsToList (name: value: {
          name = exportName declaration.name name;
          value =
            if lib.isDerivation value
            then value
            else fail "${kind} '${exportName declaration.name name}' is not a derivation";
        })
        definitions)
      ordered;
    in
      unique kind entries;
  in
    builtins.seq declarations {
      inherit declarations;
      commonArgs = validatedCommonArgs;
      mkHost = makeHost;
      nixosModules = namedModules "nixos";
      homeModules = namedModules "home";
      perSystem = {
        system,
        pkgs,
        ...
      }: {
        packages = collect "package" system pkgs;
        checks = collect "check" system pkgs;
      };
    };

  mkHost = {
    modules,
    commonArgs ? {},
    ...
  } @ specification:
    (mkRegistry {inherit modules commonArgs;}).mkHost
    (builtins.removeAttrs specification ["modules" "commonArgs"]);

  discover = import ./discovery.nix {inherit lib mkModule mkRegistry inputs self;};
}
