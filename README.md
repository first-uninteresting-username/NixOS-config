# NixOS Config

A comprehensive OS-as-a-code solution based on NixOS (Work in progress).

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/first-uninteresting-username/NixOS-config)
![Hackatime Badge](https://hackatime.hackclub.com/api/v1/badge/U0A9Y38B28H/first-uninteresting-username/NixOS-config)
[![Flake check](https://img.shields.io/github/actions/workflow/status/first-uninteresting-username/NixOS-config/flake-check.yaml?label=flake+check&logo=nixos&logoColor=5277C3)](https://github.com/first-uninteresting-username/NixOS-config/actions/workflows/flake-check.yaml)
[![Docs](https://img.shields.io/github/actions/workflow/status/first-uninteresting-username/NixOS-config/docs.yaml?label=docs&logo=readthedocs&logoColor=white)](https://first-uninteresting-username.github.io/NixOS-config/)
[![Release](https://img.shields.io/github/v/release/first-uninteresting-username/NixOS-config?logo=github)](https://github.com/first-uninteresting-username/NixOS-config/releases)
[![License](https://img.shields.io/github/license/first-uninteresting-username/NixOS-config?logo=gnu)](LICENSE)
[![Issues](https://img.shields.io/github/issues/first-uninteresting-username/NixOS-config?logo=github)](https://github.com/first-uninteresting-username/NixOS-config/issues)
[![Built with Nix](https://img.shields.io/badge/built_with-Nix-5277C3?logo=nixos&logoColor=white&style=flat)](https://nixos.org)

> [!IMPORTANT]
> If you wish to use any part of this config (not by copying parts of nix code, but actual modules),
> please let me know with a [Github issue](https://github.com/first-uninteresting-username/NixOS-config/issues)

## Desktop screenshot

<img width="2560" height="1440" alt="a screenshot of gnome desktop" src="https://github.com/user-attachments/assets/f830e17d-349e-490e-a18c-c1f716d087b1" />

## Features

- [Behavioral checks and CI policy](docs/checks.md)
- [Preservation](https://github.com/nix-community/preservation)
- [Documentation on github pages](https://first-uninteresting-username.github.io/NixOS-config/)
- Caching (thanks to [cachix](https://www.cachix.org/))
- Module-owned configuration, packages, checks, and local documentation through the
  [modules-v3 registry](docs/modules.md), which also generates the flake outputs
- All the usual nixos goodies
- Everything you could expect from a polished linux desktop setup, but declarative :)

## Hosts Matrix

| Hostname | Motherboard / Laptop Model | CPU         | GPU               | RAM  | Primary Purpose  |
| -------- | -------------------------- | ----------- | ----------------- | ---- | ---------------- |
| armin    | Framework 13               | Ryzen 7640U | Radeon 760M       | 16GB | Desktop (GNOME)  |
| john     | N/A                        | N/A         | N/A               | N/A  | Installation ISO |
| wall-e   | N/A                        | N/A         | N/A               | N/A  | Installation ISO |
| victim   | Gigabyte Eagle B650 AX     | Ryzen 7500F | Radeon RX 7800 XT | 32GB | Desktop (GNOME)  |

## Quickstart

> [!IMPORTANT]
> Password for the ISO is `nixos`

The config can be tested using the bootable ISO from [github releases](https://github.com/first-uninteresting-username/NixOS-config/releases).
Note that the ISO is hosted on sourceforge, so the download might be really slow.
Another way to acquire the ISO is to build it (with cache).
Run:

```bash
# Build the terminal ISO by replacing `host-john` with `host-wall-e`
nix build github:first-uninteresting-username/NixOS-config#host-john
# Accept all prompts or you will be building the full ISO
```

If your only goal is to test the config, you can boot the ISO in a nix managed VM with:

```bash
nix run github:first-uninteresting-username/NixOS-config#nixosConfigurations.john.config.system.build.vm
```

To use modules or packages from this flake in your own configuration, add it as an input:

```nix
inputs.nixos-config.url = "github:first-uninteresting-username/NixOS-config";
```

Then, include the desired modules in your `nixosSystem`:

```nix
modules = [
  inputs.nixos-config.nixosModules.audio
  # Supply the declared arguments through specialArgs
];
```

For detailed instructions on internal and external usage, see the [Usage Guide](docs/usage.md).

## Documentation

Zensical builds the [repository documentation](https://first-uninteresting-username.github.io/NixOS-config/).
Every host also installs documentation for its selected modules, combined imperative steps,
and the common-argument reference. Run `open-docs` for Lynx or open the host documentation
entry in the application menu. See [host documentation](docs/modules.md#read-host-documentation).

## Workspace overview

```text
arguments/          Shared typed arguments and defaults
hosts/              Host names, systems, ID selections, and argument values
modules/            Module-owned system/home configuration, packages, and checks
lib/modules/        Discovery, constructors, and focused fixtures
github-actions/     Flake CI matrices and regression outputs
.github/            Workflows and CI policy
docs/               User documentation
secrets/            Encrypted secrets
```

Underscore-prefixed files and directories are excluded from discovery. Hardware and disk
sources live with their host-specific module. See [modules](docs/modules.md) for the v3
contract and [library API](lib/modules/README.md) for the constructors.

## Known issues

None

## Footnote

### Inspired by:

- [ryan4yin/nix-config](https://github.com/ryan4yin/nix-config) — Helped me a lot in the later stages of the project. Golden standard for NixOS configs.
- [wimpysworld/nix-config](https://github.com/wimpysworld/nix-config) — Great docs and unique way of enabling modules. Very interesting config.
- [Tarow/nix-podman-stacks](https://github.com/Tarow/nix-podman-stacks) - Extremely helpful for setting up my own homelab. Highly recommended.

### License

This project is licensed under the GNU General Public License v3.0 or later.
See the [LICENSE](LICENSE) file for details.

NixOS Logo designed by Tim Cuthbertson (@timbertson).

The NixOS logo is licensed under the [Creative Commons Attribution 4.0
International License](http://creativecommons.org/licenses/by/4.0/).
