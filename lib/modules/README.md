# Modules library

This library implements the modules-v3 constructors and output-ownership metadata.
The root flake discovers all production modules, hosts, and common arguments
through it, takes its flake outputs from the result, and generates local documentation for
every host. Checks-v4 CI selects affected checks and packages from module ownership at the
merge base and head revisions.

## Entry points

Import the library with the flake inputs:

```nix
moduleLib = import ./lib/modules { inherit inputs self; };
```

- `mkModule` declares a named module.
- `mkRegistry { modules; commonArgs; }` validates names and provides `mkHost`,
  `nixosModules`, `homeModules`, and a `perSystem { system; pkgs; }` function returning
  that system's `packages` and `checks`.
- `mkHost { modules; commonArgs; name; role; system; ids; args; }` provides the same
  host constructor without first binding a registry. `commonArgs`, `ids`, and `args`
  default to empty values. `role` is `"nixos"` or `"home"`.
- `discover { modulesDir; hostsDir; argumentsDir; systems; }` creates a registry from three
  explicit directory roots and adds `nixosConfigurations` and `homeConfigurations`. For each
  listed system, it also adds `packages.<system>` and `checks.<system>`, built with that
  system's default Nixpkgs. `systems` defaults to an empty list.

The root flake uses the discovered registry's outputs directly and exposes only its `mkHost`
and `commonArgs` as `lib.modules`, for checks and packages that need them.

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
is a separate function returning a list of ordinary assertion/message records, optionally
wrapped in `lib.mkIf` or combined with `lib.mkMerge`. Disabled conditions do not evaluate
their assertion lists. Context-specific assertions belong inside the corresponding section.
A NixOS-only declaration contributes
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

## Host documentation

Every constructed host automatically installs its documentation package. `open-docs` opens
the local HTML in Lynx, even in a graphical session. It accepts Lynx flags, for example
`open-docs -dump`. The application menu's host documentation entry uses `xdg-open` to open
the same site in a graphical browser. Neither entry point executes imperative steps.

The host result exposes `documentation.source`, `documentation.site`, `documentation.openDocs`,
`documentation.desktop`, and `documentation.package` derivations. For example:

```bash
nix build .#nixosConfigurations.armin.documentation.package
./result/bin/open-docs
```

Zensical builds static HTML with relative file links and bundled assets; no web server is
required. Worker-based search is disabled for local-file access; use the page navigation
and the browser's find command. The site follows the browser's light/dark preference and
provides a theme toggle. The bundled NixOS snowflake supplies the favicon. Each module
with content gets a page, and the site includes
a combined imperative-steps page sorted by module name and the common-argument reference.
Missing, null, empty, and whitespace-only content is omitted. Selection uses host IDs,
including selected NixOS-only modules on standalone Home Manager hosts.

`docs` and `imperativeSteps` each accept Markdown text, null, or a function returning either.
Functions request named host arguments and library context explicitly, using the same
host-value, function-default, common-default precedence as configuration. Documentation
functions also have explicit `role` and `system` context, but no evaluated system or home
`config`. Documentation-only arguments are recognized when validating host arguments.

```nix
docs = { hostName }: "Local documentation for `${hostName}`.";
imperativeSteps = { role, preservationEnable }:
  if role != "nixos" then null
  else "Prepare the ${if preservationEnable then "/persist" else "system"} state.";
```

Use `role` guards for system-specific text on standalone Home Manager hosts. Documentation
arguments are lazy: the home branch above does not require `preservationEnable`. Do not
interpolate secret values into documentation, which is stored in the public Nix store.
Read companion Markdown explicitly with `builtins.readFile` when plain strings are unwieldy.

## Output ownership

`registry.ownership { root; system; pkgs; }` produces JSON-serializable metadata with
`schemaVersion = 2`, `system`, and `packages` and `checks` maps keyed by final export
names. Pass the repository root as `root`. Each target records its declaring `module`,
repository-relative `source` and `directory`.
Discovery supplies the source locations automatically. Metadata fails for exported targets
without source locations or outside the supplied root, and rejects export collisions and
invalid derivations just as the normal exports do.

Checks export derivations directly, just like packages. There is no cross-module watched-file
API. Per-system conditions apply equally to exports and metadata, so omitted
architecture-specific checks have no ownership entry. Multiple declarations in one directory
retain that directory as their shared trigger.

`githubActions.selection` exports this metadata for every supported system together with
ordinary and ISO package/check matrices. CI validates that metadata and exported targets
agree in both directions at each revision. The selector compares merge-base and head
snapshots, watches whole module directories, and follows moved
modules to their current exports. Removed targets appear in diagnostics without requesting
nonexistent builds. Shared changes select the full non-ISO suite; the ISO tier stays separate.
A base without the snapshot selects the full non-ISO suite for the initial migration.
Snapshot evaluation errors and malformed or incomplete metadata fail discovery. Older schema-1
snapshots remain readable for merge-base comparisons; their `extraFiles` do not affect selection.
The explicit core-infrastructure list in `.github/scripts/select-tests.py` selects all ordinary
outputs. Unrelated modules, host declarations, development tools, and other workflows do not.

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

This is an intentional API boundary: a common argument's type does not validate an omitted
function parameter's default. For example, `examplePort ? "wrong-type"` remains a string
even if the common declaration uses `lib.types.port`. Keep lexical defaults type-correct;
request a required parameter to use the validated common default instead. Explicit host
overrides still undergo common-type validation, including for optional parameters. Retaining
Nix's lexical defaults also supports expressions referring to enclosing bindings and other
parameters without introducing a separate default-value API.

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
files return one host specification or a list. Discovery calls the registry’s `mkHost`
for each specification; host files do not call it or manually import registry declarations. Common-argument files return an attribute
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
and evaluates production-module standalone Home Manager activation derivations on both supported
systems without building their application dependencies.
The exports check builds only the synthetic package/check artifacts. The evaluation check owns
the pure assertions and production-home evaluation. Its selected CI job runs diagnostic checks
for that job's architecture:

```bash
python3 lib/modules/tests/run.py --diagnostics-only --system <system>
```

Basic CI does not run the separate fixture runner. Full flake evaluation still validates all
exported check derivations without executing their builds.
