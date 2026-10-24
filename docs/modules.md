# Modules

The modules-v3 registry discovers declarations under `modules/`, host selections under
`hosts/`, and common arguments under `arguments/`. Each module owns its configuration,
packages, checks, documentation, and companion sources. See the
[library API][module-api].

## Select modules

Hosts declare `name`, `role` (`nixos` or `home`), `system`, `ids`, and `args`.
A module is selected when the host contains every one of its IDs. Empty IDs match all
hosts. IDs do not add dependencies automatically. The `GNOME` ID selects GNOME and its
complete utility set. Select `nushell` or `zsh` for the login shell and `shell` for shared
command-line tools. Hosts also explicitly select related IDs such as `wayland`, `stylix`,
and `home-manager`. The `hack` ID selects Hack and its API-key integration. Stylix uses
MoreWaita icons directly; desktop, shell, and icon choices need no host arguments.

IDs need no matching empty module declaration. A module exists only when it contributes
configuration, state, packages, checks, assertions, or documentation.

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

## Declare state

Declare the paths a module needs across reboots in its `state` field, not in
`preservation` options:

```nix
mkModule {
  name = "example";
  ids = ["example"];
  state = {
    nixos.directories = ["/var/lib/example"];
    home = {config}: {
      directories = [".local/share/example" config.programs.firefox.configPath];
      files = [".config/example/settings.json"];
    };
  };
}
```

System paths are absolute. Home paths are relative to the user's home directory, and a
`home` function receives the Home Manager `config`. Entries can also be attribute sets in
the preservation format, such as `{directory = ".ssh"; mode = "0700";}`. Use functions with
`lib.optional` for conditional state, for example on `secretsEnable`.

The `preservation` module keeps the collected state under `/persist` when
`preservationEnable` is true. Modules therefore need neither `preservationEnable` nor
`userName` for persistence. Each host's documentation lists its declared state.

## Packages and checks

A module's `default` package exports under its module name. Other packages export as
`<module>-<package>`; checks follow the same rule. Exports exist independently of host
selection. Installing a package requires an explicit system or home setting.

For example, `programs-desktop` installs Inkscape and Flow Desktop and exports
`programs-desktop-flow-desktop`. Other renamed outputs include `update-rebuild`,
`secrets-sops-easy`, `GNOME-hackastats`, and `GNOME-hexecute-gnome`.
ISO packages are `host-john` and `host-wall-e`; their checks remain `iso-john` and
`iso-wall-e` in the separate ISO tier.

Packages that pin an upstream release declare `passthru.updateScript` with
`pkgs.nix-update-script`. Run `nix run .#update-packages` to update them; see
[package updates](package-updates.md).

Checks use independent fixtures with explicit argument values. Existing VM checks live in
module-local `_checks/` directories, and KVM checks run only on x86_64-linux.
CI selects affected checks and packages from generated ownership metadata at the merge
base and head revisions. Module directories and explicitly watched files trigger their
owned targets; shared infrastructure changes select the full non-ISO suite. The
[checks guide](checks.md) describes selection, validation, and the separate ISO tier.

## Application sandboxes

Application modules use `self.lib.mkJail` for shared jail.nix defaults and per-app
permissions. See [application sandboxes](sandboxing.md) for the helper API, current
coverage, and access boundaries.

## Read host documentation

Every host automatically installs its own static HTML documentation. Run `open-docs` to
read it in Lynx, or use the host documentation entry in the application menu to open it
in a graphical browser. Both entry points work with local files and do not require a server.

The site includes pages for selected modules supplying `docs` or `imperativeSteps`, a
combined imperative-steps page sorted by module name, a State page listing declared state
by module, and the common-argument reference.
Opening a page does not execute its instructions. Selected modules without content do
not produce empty pages.

Module declarations can supply plain Markdown or functions requesting host arguments:

```nix
docs = {hostName}: "Configuration for `${hostName}`.";
imperativeSteps = {role, userName}:
  if role == "home" then "Prepare the home directory for `${userName}`." else null;
```

Use `role` guards for instructions that only apply to one host role. Only arguments used
by the resulting text are evaluated. Never embed secret values in generated documentation.
The [library API][host-documentation] describes the available context.

Build the documentation without building or activating the system:

```bash
nix build .#nixosConfigurations.armin.documentation.package
./result/bin/open-docs
```

## Regenerate the argument reference

```bash
nix run .#module-docs-update
```

The reference is generated; do not edit it manually.

[module-api]: https://github.com/first-uninteresting-username/NixOS-config/blob/main/lib/modules/README.md
[host-documentation]: https://github.com/first-uninteresting-username/NixOS-config/blob/main/lib/modules/README.md#host-documentation
