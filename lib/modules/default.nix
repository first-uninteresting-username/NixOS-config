# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  inputs,
  self ? {},
  lib ? inputs.nixpkgs.lib,
}: let
  arguments = import ./arguments.nix {inherit lib;};
  fail = message: throw "modules: ${message}";
  unique = kind: entries:
    builtins.foldl' (acc: entry:
      if builtins.hasAttr entry.name acc
      then fail "duplicate ${kind} name '${entry.name}'"
      else acc // {${entry.name} = entry.value;}) {}
    entries;
  validName = name: builtins.isString name && builtins.match "[a-zA-Z0-9][a-zA-Z0-9_-]*" name != null;
  idsValid = ids: builtins.isList ids && builtins.all builtins.isString ids;
  # Context comes from the evaluator; only the remaining names are host arguments.
  contextNames = ["config" "options" "lib" "pkgs" "inputs" "self" "system" "role" "packages" "osConfig" "modulesPath" "specialArgs"];
  hostRequests = fn: builtins.filter (name: !(builtins.elem name contextNames)) (arguments.requests fn);
  documentationRequests = declaration:
    lib.concatMap (field:
      lib.optionals (builtins.isFunction declaration.${field}) (hostRequests declaration.${field}))
    ["docs" "imperativeSteps"];
  # A NixOS-only body must not force arguments or assertions on a standalone home.
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
    # Exports use explicit package context, independent of selecting any real host.
    packageSet = system: pkgs: declaration: let
      context = baseContext // {inherit system pkgs;};
      bound = call "module '${declaration.name}' packages" {} context {} declaration.packages;
      definitions =
        if builtins.isFunction declaration.packages
        then builtins.seq bound.required bound.value
        else declaration.packages;
    in
      definitions;
    # Every generated system module composes the same single-user HM integration.
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
    # Bind the outer declaration first, then evaluate each section in its own context.
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
      # Home sections need the embedded user’s config, not the surrounding system config.
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
      # Resolve conditional lists with the public module API before adding diagnostics.
      resolvedAssertions =
        (lib.evalModules {
          modules = [
            {
              options.assertions = lib.mkOption {
                type = lib.types.listOf lib.types.unspecified;
                default = [];
              };
              config.assertions = assertions.value;
            }
          ];
        }).config.assertions;
      shared = {
        assertions =
          builtins.seq outer.required (builtins.seq assertions.required
            (map (entry: entry // {message = "${label}: ${entry.message}";}) resolvedAssertions));
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
      documentation = import ./documentation.nix {
        inherit lib pkgs name;
        commonArgs = validatedCommonArgs;
        pages =
          lib.filterAttrs (_: page: page.docs != null || page.imperativeSteps != null)
          (builtins.listToAttrs (map (declaration: {
              inherit (declaration) name;
              value = lib.genAttrs ["docs" "imperativeSteps"] (field: let
                input = declaration.${field};
                # A role guard can omit text without forcing system-only arguments on home hosts.
                text =
                  if builtins.isFunction input
                  then (call "${labelFor name declaration} ${field}" values (context // {inherit role;}) {} input).value
                  else input;
              in
                if text == null
                then null
                else if !(builtins.isString text)
                then fail "${labelFor name declaration} ${field}: expected Markdown text or null"
                else if builtins.match "[[:space:]]*" text != null
                then null
                else text);
            })
            chosen));
      };
      bodyFor = declaration: (call (labelFor name declaration) values context {} declaration.module).value;
      # Discover requests lazily so inactive sections impose no argument requirements.
      requested = targetRole: declaration: let
        body = bodyFor declaration;
      in
        lib.optionals (applicable targetRole body)
        (hostRequests declaration.module
          ++ hostRequests declaration.assertions
          ++ lib.concatMap (section: hostRequests body.${section}) (sectionNames targetRole body));
      known = lib.unique (["userName"]
        ++ builtins.attrNames validatedCommonArgs
        ++ lib.concatMap (declaration: requested "nixos" declaration ++ documentationRequests declaration) ordered);
      used =
        lib.unique (lib.optionals (role == "nixos") ["userName"]
          ++ lib.concatMap (declaration: requested role declaration ++ documentationRequests declaration) chosen);
      unknown = builtins.filter (arg: !(builtins.elem arg known)) (builtins.attrNames args);
      unused = builtins.filter (arg: !(builtins.elem arg used)) (builtins.attrNames args);
      checked =
        if unknown != []
        then fail "host '${name}': unknown arguments: ${lib.concatStringsSep ", " unknown}"
        else lib.warnIf (unused != []) "modules: host '${name}': unused arguments: ${lib.concatStringsSep ", " unused}" true;
      compiled = map (compile role values name) chosen;
      result =
        if role == "nixos"
        then
          inputs.nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [(integration values name) {environment.systemPackages = [documentation.package];}] ++ compiled;
          }
        else
          inputs.home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            modules = [{home.packages = [documentation.package];}] ++ compiled;
          };
      # Check embedded homes too; their assertions are not system-level assertions.
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
        else result // {inherit documentation;}
      ));
    # Normalize check records before validating names, derivations, and watched paths.
    outputEntries = kind: system: pkgs:
      lib.concatMap (declaration: let
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
        lib.mapAttrsToList (name: definition: let
          wrapped = kind == "check" && builtins.isAttrs definition && !(lib.isDerivation definition);
          value =
            if wrapped
            then definition.derivation or null
            else definition;
          extraFiles =
            if wrapped
            then definition.extraFiles or []
            else [];
          validFiles =
            builtins.isList extraFiles
            && builtins.all (path:
              builtins.isString path
              && path != ""
              && !(lib.hasPrefix "/" path)
              && builtins.all (part: !(builtins.elem part ["" "." ".."])) (lib.splitString "/" path))
            extraFiles;
        in {
          name = exportName declaration.name name;
          inherit declaration extraFiles;
          value =
            if wrapped && builtins.removeAttrs definition ["derivation" "extraFiles"] != {}
            then fail "check '${exportName declaration.name name}' has unknown fields"
            else if !validFiles
            then fail "check '${exportName declaration.name name}' extraFiles must be repository-relative file names"
            else if lib.isDerivation value
            then value
            else fail "${kind} '${exportName declaration.name name}' is not a derivation";
        })
        definitions)
      ordered;
    collect = kind: system: pkgs: unique kind (outputEntries kind system pkgs);
    # CI compares repository-relative ownership at both revisions, including removals.
    ownership = {
      root,
      system,
      pkgs,
    }: let
      prefix = lib.removeSuffix "/" (toString root) + "/";
      relative = label: path: let
        text = toString path;
      in
        if text == lib.removeSuffix "/" prefix
        then "."
        else if lib.hasPrefix prefix text
        then lib.removePrefix prefix text
        else fail "${label}: source must be inside the repository root";
      targets = kind: let
        entries = outputEntries kind system pkgs;
        exports = unique kind entries;
        validExports = builtins.all (value: builtins.seq value true) (builtins.attrValues exports);
      in
        builtins.seq validExports (builtins.listToAttrs (map (entry: {
            inherit (entry) name;
            value =
              if !(entry.declaration ? source && entry.declaration ? directory)
              then fail "module '${entry.declaration.name}': ownership requires discovered source and directory"
              else {
                module = entry.declaration.name;
                source = relative entry.declaration.name entry.declaration.source;
                directory = relative entry.declaration.name entry.declaration.directory;
                inherit (entry) extraFiles;
              };
          })
          entries));
    in {
      schemaVersion = 1;
      inherit system;
      packages = targets "package";
      checks = targets "check";
    };
  in
    builtins.seq declarations {
      inherit declarations ownership;
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
