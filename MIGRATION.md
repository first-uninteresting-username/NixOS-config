# Modules v3 and checks v3

## Status and scope

This document records the agreed design for replacing the current module system and
checks v2. It specifies the target contract for the complete migration.

Steps 1–2 now have an opt-in library implementation and focused fixtures under
[`lib/modules-v3`](lib/modules-v3/README.md). Its README documents the chosen API and
validation commands. Production configuration and CI remain on the existing system;
the remaining migration steps are not implemented by this library work.

Replace the old system in one migration. Do not introduce a supported period of mixed
v2 and v3 hosts. Preserve existing host behavior unless a change is explicitly part of
this specification. Do not activate or deploy configurations as part of the migration.

## Building blocks

- `mkModule` keeps system configuration, home configuration, packages, checks, assertions,
  documentation, and imperative instructions together.
- `mkHost` selects modules using IDs and supplies host arguments. It produces either a
  NixOS configuration or a standalone Home Manager configuration.
- Common argument declarations define shared argument types, descriptions, and defaults.
- Flake-parts continues to provide per-system package and check outputs for
  `x86_64-linux` and `aarch64-linux`.

Modules, hosts, and common argument declarations each have their own discovery directory.
Discovery is automatic. Underscore-prefixed files and directories remain excluded.

Each module has its own directory, including its associated scripts, fixtures, and
package sources. Multiple module declarations in one file are allowed but discouraged.

## IDs and selection

A host selects a module exactly when it contains every ID declared by that module:

```text
selected(module, host) = every module.ids entry is present in host.ids
```

IDs are plain selection values. There is no dependency resolver, automatic addition of
IDs, separate module dependency declaration, explicit module inclusion, or exclusion
override. There is no limit on the number of IDs.

Omitted module IDs default to `[]`. An empty list matches every host. Modules with equal
ID sets are selected together, with no ordering implied.

For example, a host with `["base" "desktop" "gaming"]` selects:

| Module IDs | Selected |
| --- | --- |
| `[]` | Yes |
| `["desktop"]` | Yes |
| `["gaming"]` | Yes |
| `["desktop" "gaming"]` | Yes |
| `["desktop" "server"]` | No |

Selecting a module with `["desktop" "gaming"]` necessarily selects modules requiring
only `["desktop"]`, only `["gaming"]`, or no IDs. These are modules imported alongside
it, not a dependency graph. A host with only `["gaming"]` does not select it.

## mkModule

### Declaration

A declaration has an explicit, unique module name. Reject duplicate module names.

It can contain:

- IDs, defaulting to an empty list.
- A configuration function with explicit requested arguments.
- Separate NixOS and Home Manager section functions, each with its own evaluation context.
- Any number of package declarations.
- Any number of check declarations with explicit fixture values.
- An optional assertions section using ordinary NixOS-style assertions.
- Optional general documentation and a separate optional imperative-steps input.

There is no `types` or `roles` field on `mkModule`.

The following is a schematic configuration-function shape, not executable implementation:

```nix
module = {userName, port-example ? 8080}: {
  nixos = {config, lib, pkgs, packages, ...}: {
    # System configuration uses its own config.
  };

  home = {config, lib, pkgs, packages, ...}: {
    # Home Manager configuration uses its own config.
  };
};
```

Module-specific argument defaults use ordinary Nix function parameters. Common arguments
are declared separately. Requesting an argument at the enclosing level makes it available
to both sections. Keep section-specific requirements in the appropriate section's argument
requests so an inactive NixOS section does not impose requirements on Home Manager hosts.

### Configuration exports

Generate named NixOS and Home Manager module exports from each declaration.

The generated NixOS module contains its system section and embeds its home section under
`home-manager.users.${userName}`, following the current repository's inline arrangement.
A declaration containing only a home section still generates this NixOS wrapper.

Home Manager integration belongs to `mkModule`, not `mkHost`. Generated modules must
compose without conflicting integration definitions.

A standalone Home Manager host evaluates only the home section. A selected module with
only a NixOS section silently contributes nothing to that host. Its NixOS-only arguments
and assertions must not be evaluated or required. Arguments used by the home section or
both sections remain required as applicable.

Direct consumers of exported modules supply declared arguments through module arguments.
Do not expand this migration into a separate external-consumer API project.

### Arguments and evaluation context

Replace repository-defined `custom.*` options with arguments. Continue using upstream
NixOS and Home Manager options normally.

Common argument declarations provide a type, description, and optional default. Generate
documentation from those declarations. A common argument is required only when a selected,
applicable module requests it, unless host construction itself needs it.

Module-specific arguments use ordinary function parameters and optional parameter defaults.
Use distinct descriptive names such as `port-module1` and `port-module2` for unrelated
settings. Names such as `userName` intentionally refer to shared settings.

Resolve argument values in this order:

1. Explicit host value.
2. Module function parameter default.
3. Common argument declaration default.

Overriding a common default with a module default is supported but should be unusual.
Missing required arguments fail when evaluating the selecting host, not unrelated hosts.
Diagnostics identify the host, module, and argument.

Unknown host argument names fail. Known arguments unused by a host's applicable module
sections produce warnings.

Only explicitly requested host arguments are available to a module. No enclosing-function
context such as `lib`, `inputs`, or `self` is supplied automatically; the declaration must
explicitly request the context it needs. Section functions retain their proper NixOS or
Home Manager evaluation context. Both can request the module's own `packages`.

### Packages

One module can declare multiple packages. Export them through flake-parts per-system
package outputs, independently of whether any host selects the declaring module.

Prefix exported names with the module name. A package named `default` exports under the
module name itself; other packages export as `<module>-<package>`. For example, module
`example` exports `default` as `example` and `helper` as `example-helper`.

Reject collisions in the final exported package namespace, including collisions caused
by prefixing or default-name expansion.

Exporting a package does not install it. The module explicitly installs its packages in
`environment.systemPackages`, `home.packages`, or another appropriate option. Both system
and home sections can access the module's packages.

Exported packages use their own values rather than producing a separate export for every
host. When package construction needs host values, define a local lambda inside the module
using `let ... in`, and instantiate it where needed. Do not export host-dependent functions
as ordinary flake package derivations or create an additional public factory API.

A module does not consume another module's package exports. The declaring module owns
configuration involving its packages. Closely related configuration uses appropriate ID
selection to ensure the relevant modules are present together.

### Checks and assertions

One module can declare multiple checks. Checks provide their own explicit fixtures and
values rather than inheriting values from real hosts. Exercise production modules through
those fixtures.

Export checks through flake-parts. Apply the same naming convention as packages:
`default` becomes `<module>`, and other checks become `<module>-<check>`. Reject collisions
in the final check namespace.

Retain meaningful behavioral checks and regression coverage. Avoid tests that merely
repeat configuration assignments or duplicate upstream tests.

Assertions use the ordinary assertion/message form. They can validate declared arguments
and applicable evaluated configuration, and can be conditional. Apply applicable shared
assertions to standalone Home Manager too; keep NixOS-specific assertions in the system
context. A failed applicable assertion fails evaluation.

Modules themselves are independent of the host system and have no supported-systems field.
Package and check declarations can use per-system conditions where required. Do not run
KVM-dependent checks on `aarch64-linux`.

## mkHost

A host declaration supplies:

- Its name, from which `hostName` is derived.
- A role selecting NixOS or standalone Home Manager output.
- An explicit `system` field, separate from `args`.
- IDs used exclusively for module selection.
- Explicit argument values other than the derived `hostName`.

Each NixOS host has exactly one Home Manager user, embedded through the selected generated
modules. There is no NixOS-host mode that excludes Home Manager.

All configuration goes through `mkModule`, including hardware, disks, user creation,
state versions, and other host-specific settings. `mkHost` has no arbitrary inline
configuration or module-import escape hatch. Use host arguments and suitable IDs for
host-specific behavior.

Preserve existing system and home state versions. Host declarations do not activate or
deploy the resulting configuration.

## Checks v3 and CI selection

Replace checks v2's manually maintained ownership map with metadata produced by module
declarations. Keep check and package ownership tied to the declaring source and directory.

### Pull requests

- Always run basic formatting, lint, evaluation, and CI-policy validation.
- A change anywhere in a module directory selects all checks and exported packages declared
  by modules in that directory.
- A check can additionally list other files that trigger it.
- Shared helper, common argument, lock-file, and shared infrastructure changes select the
  full applicable check and package suite, retaining the separate ISO tier.
- A module without checks adds no behavioral checks merely because it changed. Basic
  validation still runs, and its declared packages still follow package selection.
- Build only affected packages, replacing checks v2's all-packages-on-every-PR policy.
- Respect per-system output availability, including the KVM restriction above.

Preserve checks v2's handling of complete PR diffs, deleted files, and both paths of renamed
files. Selection must account for declarations removed or moved by the change rather than
depending exclusively on ownership metadata remaining at the head revision.

Keep selection diagnostics and validate generated metadata against exported targets.
Preserve the stable required aggregate status `all-systems-passed`. An intentionally empty
selection can skip its build tier; unexpected skips and selection failures must fail the
aggregate. Update checks-v2 policy tests for checks v3.

### Full and ISO runs

Retain full scheduled/manual validation, host builds, the separate ISO image and smoke-test
tier, regression-proof runs, caching, and failure logs. Adapt target discovery to the new
exports and naming rather than retaining hard-coded assumptions that no longer hold.

## Host documentation

Documentation is automatic and unconditional for every host. Build static HTML with the
configuration and package it locally. Use Zensical as the preferred generator; another
generator is acceptable if implementation constraints justify it.

Include only modules selected for that host. Selection here follows IDs, including a
selected NixOS-only declaration on a standalone Home Manager host. Documentation fields
are optional; silently omit missing content.

Generate one page per module with supplied content in this shape:

```markdown
# MODULE NAME

## Module docs

General module documentation.

## Imperative steps

Manual setup instructions.
```

Omit empty sections. General docs and imperative steps are separate inputs and may contain
declared argument values. Do not require argument interpolation when plain Markdown works.
Argument-dependent documentation must respect which arguments apply to the host.

Generate an additional combined imperative-steps page, grouped alphabetically by module
name. Include only modules supplying imperative steps. Use a module-name heading followed
by that module's steps. Document prerequisites involving another module in the text;
do not introduce an execution or ordering dependency system.

Generate common-argument reference documentation from the shared declarations as well.
Do not turn the requested module pages into an exhaustive metadata listing unless it helps
the documentation.

Provide both entry points:

- A desktop entry opens the generated HTML in a graphical browser.
- An `open-docs` command always opens the local documentation in a terminal browser, such
  as Lynx. Supply the command as a package and install it automatically on hosts.

Imperative steps remain instructions. Generating or opening documentation does not execute
them. Verify that the generated site works locally in graphical and terminal browsers.

## Migration work

Complete the replacement together rather than migrating individual production hosts into
a supported mixed system.

1. Implement discovery, common argument declarations, `mkModule`, and `mkHost`.
2. Validate ID matching, argument resolution, inactive-section behavior, assertions, and
   export naming with focused fixtures.
3. Convert all current modules, packages, checks, and host-specific configuration. Replace
   `custom.*` consumers with declared arguments while preserving existing host behavior.
4. Generate per-host documentation, the combined instructions, desktop entries, and
   `open-docs`.
5. Implement checks-v3 metadata and affected-target selection. Update CI policy tests and
   existing behavioral/regression fixtures.
6. Update repository guidance and documentation to describe the replacement. Replace the
   old custom-option documentation generator and freshness check as appropriate. Do not
   hand-edit the generated module reference or edit `docs/usage.md` without a new request.
7. Remove obsolete v2 wiring and ownership maps once all callers use v3.

Validate formatting and full flake evaluation on both systems. Build affected packages,
documentation, applicable behavioral checks, and host configurations where practical.
Verify standalone Home Manager separately, including silent omission of NixOS-only
configuration. Verify CI selection for module-directory changes, extra watched files,
global changes, empty selections, renames, and deletions.

Evaluation does not execute VM checks. Report build, network, store-permission, and
virtualization limitations accurately. Review resulting host behavior before deployment;
deployment remains a separate action.

## Implementation details still to choose

The behavior above is agreed. Exact constructor field names and layout, discovery-directory
paths, the argument-binding implementation, the browser package, and documentation styling
remain implementation choices. They must preserve this contract; changing selection,
argument precedence, output ownership, or host behavior requires revisiting the design.
