# Modules

The modules-v3 registry discovers declarations under `modules/`, host selections under
`hosts/`, and common arguments under `arguments/`. Each module owns its configuration,
packages, checks, documentation, and companion sources. See the
[library API](../lib/modules/README.md) and [migration status](../MIGRATION.md).

## Select modules

Hosts declare `name`, `role` (`nixos` or `home`), `system`, `ids`, and `args`.
A module is selected when the host contains every one of its IDs. Empty IDs match all
hosts. IDs do not add dependencies automatically. For example, the `DE` ID selects both
GNOME configuration and its utilities; hosts also explicitly select related IDs such as
`wayland`, `stylix`, and `home-manager`.

`hostName` is derived from `name`. The generated NixOS modules embed the user's home
configuration, while standalone Home Manager ignores NixOS-only sections.

## Declare configuration

```nix
{mkModule, ...}:
mkModule {
  name = "example";
  ids = ["example"];
  module = _: {
    nixos = {packages, ...}: {
      environment.systemPackages = [packages.default];
    };
    home = {config, ...}: {
      home.sessionVariables.EXAMPLE_HOME = config.home.homeDirectory;
    };
  };
  packages = {pkgs, ...}: {
    default = pkgs.writeShellScriptBin "example" "echo example";
  };
}
```

Request values explicitly in function parameters. Common arguments have types,
descriptions, and optional defaults in `arguments/`; the [argument reference](module-reference.md)
is generated from those declarations. Module-specific defaults use ordinary optional
function parameters. Explicit host values override function defaults and common defaults.
Put system-only requirements in the `nixos` function and home-only requirements in `home`.

Each module has its own directory. Place companion Nix sources in underscore-prefixed
files or directories so discovery excludes them. Modules do not import other registry
modules or consume another module's package exports.

## Packages and checks

A module's `default` package exports under its module name. Other packages export as
`<module>-<package>`; checks follow the same rule. Exports exist independently of host
selection. Installing a package requires an explicit system or home setting.

For example, `programs-desktop` installs Inkscape and Flow Desktop and exports
`programs-desktop-flow-desktop`. Other renamed outputs include `update-rebuild`,
`secrets-sops-easy`, `GNOME-hackastats`, and `GNOME-hexecute-gnome`.
ISO packages are `host-john` and `host-wall-e`; their checks remain `iso-john` and
`iso-wall-e` in the separate ISO tier.

Checks use independent fixtures with explicit argument values. Existing VM checks live in
module-local `_checks/` directories, and KVM checks run only on x86_64-linux.
The [checks guide](checks.md) describes the current CI policy. Base/head ownership-driven
selection and automatic per-host HTML documentation remain migration work.

## Regenerate the argument reference

```bash
nix run .#module-docs-update
nix build .#checks.x86_64-linux.module-docs
```

The reference is generated; do not edit it manually.
