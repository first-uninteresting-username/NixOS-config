# Modules library

This library implements the modules-v3 constructors and output-ownership metadata in
`MIGRATION.md`. The root flake discovers all production modules, hosts, and common arguments
through it. Generated host documentation and checks-v3 affected-target selection remain
later work; the current CI selector uses an updated manual map in the meantime.

## Entry points

Import the library with the flake inputs:

```nix
moduleLib = import ./lib/modules { inherit inputs self; };
```

- `mkModule` declares a named module.
- `mkRegistry { modules; commonArgs; }` validates names and provides `mkHost`,
  `nixosModules`, `homeModules`, and a flake-parts-compatible `perSystem` function.
- `mkHost { modules; commonArgs; name; role; system; ids; args; }` provides the same
  host constructor without first binding a registry. `commonArgs`, `ids`, and `args`
  default to empty values. `role` is `"nixos"` or `"home"`.
- `discover { modulesDir; hostsDir; argumentsDir; }` creates a registry from three
  explicit directory roots and adds `nixosConfigurations` and `homeConfigurations`.

The registry's `mkHost` takes only `name`, `role`, `system`, optional `ids`, and optional
`args`. It has no inline configuration or module-import field. It returns the upstream
NixOS or Home Manager evaluation result and checks applicable assertions during evaluation.
It never activates the configuration.

## Module declaration

```nix
moduleLib.mkModule {
  name = "example";
  ids = [ "desktop" ];

  module = { userName, examplePort ? 8080 }: {
    nixos = { packages, ... }: {
      environment.systemPackages = [ packages.default ];
    };
    home = { config, ... }: {
      home.file."example.txt".text =
        "${userName}:${toString examplePort}:${config.home.homeDirectory}";
    };
  };

  packages = { pkgs, ... }: {
    default = pkgs.writeText "example" "example content";
  };

  checks = { pkgs, packages, mkHost, ... }: {
    # Supply explicit fixture values to mkHost when a check needs a host.
    default = pkgs.runCommand "example-check" {} ''
      test -s ${packages.default}
      touch "$out"
    '';
  };

  assertions = { lib, ... }: [
    { assertion = lib.versionAtLeast lib.version "25.11";
      message = "Example requires a recent Nixpkgs library."; }
  ];

  docs = "General module documentation.";
  imperativeSteps = "Manual setup instructions.";
}
```

`name` is required. IDs default to `[]`; all IDs must occur in the host's IDs for a
module to be selected. Names contain letters, digits, hyphens, and underscores and start
with a letter or digit. Duplicate names fail. Modules are independent; no IDs or packages
are pulled in through dependencies.

`module` defaults to a function returning `{}`. Its `nixos` and `home` fields are optional
module functions with their respective upstream evaluation contexts. Shared `assertions`
is a separate function returning ordinary assertion/message records; context-specific
assertions belong inside the corresponding section. A NixOS-only declaration contributes
nothing to a standalone Home Manager host, including no argument or assertion requirements.
An assertion-only declaration applies to both roles.

`packages` and `checks` each accept an attribute set of derivations or a function returning
one. Their functions can explicitly request `lib`, `inputs`, `self`, `pkgs`, and `system`.
Checks can additionally request their module's `packages` and the registry's `mkHost`.
Package and check outputs exist independently of host selection. `default` exports as the
module name; other keys export as `<module>-<key>`. Final namespace collisions fail.
Gate architecture-specific outputs in these functions, for example using
`lib.optionalAttrs (system == "x86_64-linux")` for KVM checks. No VM is run by evaluation.

Each module sees only its own package set. Installing exported packages is explicit.
Host-dependent package construction stays in local lambdas inside `module` or its sections.
Exporting a function instead of a package derivation fails.

`docs` and `imperativeSteps` remain separate, unevaluated fields on `registry.declarations`.
This stage preserves them for the later documentation implementation.

## Output ownership

`registry.ownership { root; system; pkgs; }` produces JSON-serializable metadata with
`schemaVersion = 1`, `system`, and `packages` and `checks` maps keyed by final export
names. Pass the repository root as `root`. Each target records its declaring `module`,
repository-relative `source` and `directory`, and `extraFiles` (empty for packages).
Discovery supplies the source locations automatically. Metadata fails for exported targets
without source locations or outside the supplied root, and rejects export collisions and
invalid derivations just as the normal exports do.

Checks can use a derivation directly or a record carrying additional watched files:

```nix
checks = { pkgs, ... }: {
  default = {
    derivation = pkgs.runCommand "example-check" {} "touch $out";
    extraFiles = [ "shared/helper.nix" ];
  };
};
```

`extraFiles` contains literal repository-relative file names, not glob patterns. Absolute
paths, empty components, `.` and `..` components, and unknown record fields fail.
The record is unwrapped for flake check exports. Per-system conditions apply equally to
exports and metadata, so omitted architecture-specific checks have no ownership entry.
Multiple declarations in one directory retain that directory as their shared trigger.

This metadata is the input to the future checks-v3 selector; it does not replace current
CI policy yet. That selector must compare base and head metadata to account for removed
or moved declarations, process both rename paths, and retain global and ISO policies.

## Arguments and Home Manager integration

Common arguments are an attribute set of records:

```nix
commonArgs = {
  userName = {
    type = lib.types.str;
    description = "The host's Home Manager user.";
    default = "alice";
  };
};
```

Common values use Nix option types, including validation of nested values when evaluated.
Explicit host values override ordinary function defaults, which override common defaults.
Nix evaluates function defaults in their original lexical scope. These defaults are not
introspectable; type validation applies to supplied values and common defaults, while Nix
itself evaluates omitted function parameters.

Only named function parameters are passed. An ellipsis does not expose all host arguments
or all library context. Request `inputs`, `self`, or `lib` explicitly when needed. Keep
NixOS-only requirements in `nixos`, and Home Manager-only requirements in `home`.
Section structure must be discoverable without forcing missing arguments; use conditions
inside sections rather than making their existence depend on a required host value.

`hostName` is derived from the host's name and cannot appear in `args`. Unknown names in
`args` fail; names known to common declarations or any module but unused by the applicable
selected sections warn. Required missing arguments identify the host, module, and argument.
Context names such as `lib`, `pkgs`, and `config` are reserved rather than host settings.

NixOS construction requires `userName`, explicitly or through a common default. Generated
NixOS modules own Home Manager integration, share global/user packages, and embed their
home sections under that user. Multiple generated modules compose using the same integration.
Standalone Home Manager uses only the home sections. All ordinary host configuration,
including users, hardware, and state versions, must come from selected declarations.

Direct consumers import `registry.nixosModules.<name>` or `registry.homeModules.<name>`.
Supply declared values through NixOS `specialArgs` or standalone Home Manager
`extraSpecialArgs`; these also override optional function parameters. Required parameters
can additionally come from `_module.args`. Optional parameters absent from special arguments
retain their lexical defaults, so put optional overrides in special arguments.

## Discovery

Directory roots are caller-supplied. The root flake uses `modules/`, `hosts/`, and `arguments/`.
Each root is traversed recursively in sorted filename order. Only regular `.nix` files
are imported. Underscore-prefixed files and entire underscore-prefixed directories are
excluded. Put companion Nix package sources and fixtures under an underscore-prefixed
directory so discovery does not treat them as declarations.

A discovered file can be a value or a function explicitly requesting `mkModule`, `lib`,
`inputs`, or `self`. Module files return one `mkModule` result or a list of results. Host
files return one host specification or a list. Common-argument files return an attribute
set of declarations. Duplicate module names, host names, and common-argument names fail.
Declarations retain `source` and `directory` for later output-ownership metadata.

## Validation

Run the focused evaluation and diagnostic fixtures against the repository's pinned inputs:

```bash
python3 lib/modules/tests/run.py
```

Build the isolated package/check fixtures on x86_64-linux:

```bash
nix build --impure --no-link --expr \
  '(import ./lib/modules/tests { inputs = (builtins.getFlake (toString ./.)).inputs; }).build'
```

The runner evaluates both supported systems and verifies failure messages and unused-argument
warnings. The build executes a package-consuming check with its own explicit host fixture.
The root flake exports these evaluation and package/check fixtures under `module-library-*`
and adds a production-module standalone Home Manager fixture on both supported systems.
The runner additionally checks failure messages and warnings; basic CI runs it explicitly.
