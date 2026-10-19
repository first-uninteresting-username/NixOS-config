# NixOS configuration

This repository manages four NixOS hosts through the modules-v3 registry. Host IDs select
modules, and typed arguments supply shared configuration. Each module owns its system and
home configuration, packages, checks, and documentation.

## Configure a host

- [Install the configuration](install-guide.md)
- [Create a host](host-creation-guide.md)
- [Choose a host name](host-names.md)
- [Use the configuration](usage.md)
- [Read the keybindings](keybinds.md)

## Work with modules

- [Module declarations and local host documentation](modules.md)
- [Common argument reference](module-reference.md)
- [Behavioral checks and CI policy](checks.md)
- [Configuration versions](versions.md)

Building or opening documentation does not activate a configuration or execute manual
setup instructions.

See the [source repository](https://github.com/first-uninteresting-username/NixOS-config)
for the README, license, releases, and issue tracker.
