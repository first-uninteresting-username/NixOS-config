# Host creation guide

## Choose a host name and architecture

Use the [host names](host-names.md) guide for naming. The current desktop configurations
use UEFI and x86_64-linux. The flake also supports aarch64-linux package and check outputs.

## Create a host declaration

Copy `hosts/_template.nix` to `hosts/<name>.nix`, or use an existing host declaration as
the starting point for similar hardware. Set `name`, `role`, `system`, `ids`, and `args`.
The registry derives `hostName` from `name`; do not add it to `args`.

A host selects a module when it contains every module ID. Related IDs are explicit:
selecting a desktop module does not automatically select its theme or Wayland configuration.
See [modules](modules.md) and the [common argument reference](module-reference.md).

## Add host-specific configuration

Copy `modules/_template/` to `modules/host-<name>/`. Change the declaration's `name` and
ID to `host-<name>`, then include that ID in the host declaration. Put hardware settings,
state versions, disk setup, and upstream hardware imports in its `nixos` section.
The host declaration itself has no inline configuration or module-import field.

Place companion files such as `disko.nix` and `facter.json` under an underscore-prefixed
`_sources/` directory. Import the disko module and source explicitly from the host module.
Generate a hardware report on the intended host:

```bash
sudo nix run --option experimental-features "nix-command flakes" nixpkgs#nixos-facter -- -o facter.json
```

Use `modules/host-armin/` or `modules/host-victim/` as a desktop example.
Match `homeStateVersion` to the intended Home Manager compatibility version and set
`system.stateVersion` deliberately for a new installation. Preserve both on existing hosts.

## Configure users and secrets

Set `userName` and enable user creation with `userEnable`. Desktop declarations select
`desktop-password`, `secrets`, and `ssh`, which resolve encrypted credentials for the
derived host name. Set `preservationEnable` only with a suitable `/persist` filesystem.
The public credentials in ISO declarations are installation fixtures.

Edit encrypted secrets through `sops` or `sops-easy`. A desktop needs its password hash,
SSH identity, and host keys under the matching names in `secrets/secrets.yaml`.
Generate password hashes with:

```bash
mkpasswd -m yescrypt
```

Arrange the host's age identity separately. Changing `.sops.yaml` recipients requires
explicit confirmation; never commit private identities or plaintext secrets.

## Validate the configuration

```bash
alejandra hosts/<name>.nix modules/host-<name>/
nix flake check --no-build --all-systems
nixos-rebuild build --flake .#<name>
```

Build validation does not activate the configuration. Review the resulting settings before
installing or deploying. VM checks require separate builds; evaluation alone does not run them.
