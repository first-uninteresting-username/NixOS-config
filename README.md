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

> [!NOTE]
> This is a learning project in the first place.
> Please point out any issues you encounter. I will be more than happy to fix them and learn on my mistakes.

> [!IMPORTANT]
> If you wish to use any part of this config (not by copying parts of nix code, but actual modules),
> please let me know with a [Github issue](https://github.com/first-uninteresting-username/NixOS-config/issues)

## Desktop screenshot

<img width="2560" height="1440" alt="a screenshot of gnome desktop" src="https://github.com/user-attachments/assets/f830e17d-349e-490e-a18c-c1f716d087b1" />

## Features

- [Testing](checks) (that barely catches issue)
- [Preservation](https://github.com/nix-community/preservation)
- [Documentation on github pages](https://first-uninteresting-username.github.io/NixOS-config/)
- Caching (thanks to [cachix](https://www.cachix.org/))
- [Dendriatic pattern](https://github.com/mightyiam/dendritic) with [flake parts](https://flake.parts/) and [import tree](https://github.com/denful/import-tree)
- All the usual nixos goodies
- Everything you could expect from a polished linux desktop setup, but declarative :)

## Hosts Matrix

| Hostname | Motherboard / Laptop Model | CPU         | GPU               | RAM  | Primary Purpose  |
| -------- | -------------------------- | ----------- | ----------------- | ---- | ---------------- |
| armin    | Framework 13               | Ryzen 7640U | Radeon 760M       | 16GB | Desktop (GNOME)  |
| john     | N/A                        | N/A         | N/A               | N/A  | Installation ISO |
| wall-e   | N/A                        | N/A         | N/A               | N/A  | Installation ISO |
| template | N/A                        | N/A         | N/A               | N/A  | Other            |
| victim   | Gigabyte Eagle B650 AX     | Ryzen 7500F | Radeon RX 7800 XT | 32GB | Desktop (GNOME)  |

## Quickstart

> [!IMPORTANT]
> Password for the ISO is `nixos`

The config can be tested using the bootable ISO from [github releases](https://github.com/first-uninteresting-username/NixOS-config/releases).
Note that the ISO is hosted on sourceforge, so the download might be really slow.
Another way to acquire the ISO is to build it (with cache).
Run:

```bash
# Build CLI only ISO by replacing `john` with `wall-e`
nix build github:first-uninteresting-username/NixOS-config#john
# Accept all prompts or you will be building the full ISO
```

If your only goal is to test the config, you can boot the ISO in a nix managed VM with:

```bash
nix run github:first-uninteresting-username/NixOS-config#john
```

To use modules or packages from this flake in your own configuration, add it as an input:

```nix
inputs.nixos-config.url = "github:first-uninteresting-username/NixOS-config";
```

Then, include the desired modules in your `nixosSystem`:

```nix
modules = [
  inputs.nixos-config.nixosModules.audio
  # See module docs for configuration options
];
```

For detailed instructions on internal and external usage, see the [Usage Guide](docs/usage.md).

## Documentation

Docs are built with Zensical and hosted on github pages ([link](https://first-uninteresting-username.github.io/NixOS-config/))

## Workspace overview

```bash
# import tree ignores everything starting with "_" by default. That's why I use it for templates
tree
.
├── AGENTS.md
├── checks # Checks
│   ├── _example-checks # Templates for checks
│   │   ├── application.nix
│   │   ├── basic.nix
│   │   └── module-test.nix
│   ├── graphical
│   │   ├── gnome-minimal.nix # This checks if my gnome config can even boot
│   └── modules
│       └── configuration # Checks that test corresponding modules
│           ├── applications
│           │   └── _programs.nix # This check isn't ready, that's why it is ignored
│           ├── desktop
│           │   ├── printing.nix
│           │   └── wayland.nix
│           ├── developement
│           │   ├── agents.nix
│           │   └── IDE
│         ├── services
│         │   ├── update.nix
│         │   └── windows-vm.nix
│           └── system
│               └── networking.nix
├── CLA.md # Controversial CLA, I hope you can understand my motives after reading the comment
├── CONTRIBUTING.md
├── devenv.lock # Full devenv suite
├── devenv.nix
├── devenv.yaml
├── docs # Documentation, LOL
│   ├── checks.md
│   ├── host-creation-guide.md
│   ├── host-names.md
│   ├── index.md -> ../README.md # Zensical uses index.md as index for the site and I didn't want it to be empty
│   ├── install-guide.md
│   ├── keybinds.md # keybinds for all DEs are documented in this file
│   ├── module-reference.md
│   ├── modules.md
│   ├── usage.md
│   └── versions.md
├── flake.lock
├── flake.nix
├── github-actions # https://github.com/nix-community/nix-github-actions
│   └── default.nix
├── hosts # My systems using this config, refer to other documentation
│   ├── armin
│   │   ├── default.nix
│   │   ├── disko.nix
│   │   ├── facter.json
│   │   ├── hardware.nix
│   │   └── modules.nix
│   ├── common # Common nixos module declarations
│   │   ├── desktop-modules.nix
│   │   └── iso-modules.nix
│   ├── john
│   │   ├── configuration.nix
│   │   ├── default.nix
│   │   └── modules.nix
│   ├── template # I will use this host to function of each file
│   │   ├── configuration.nix # Arbitrary nixos configuration code exclusive to this host
│   │   ├── _default.nix # The core of a host, imports all other files and defines the host
│   │   ├── disko.nix # Disks declaration
│   │   ├── hardware.nix # Hardware configuration
│   │   └── modules.nix # NixOS modules with options
│   ├── victim
│   │   ├── default.nix
│   │   ├── disko.nix
│   │   ├── facter.json
│   │   ├── hardware.nix
│   │   └── modules.nix
│   └── wall-e
│       ├── configuration.nix
│       ├── default.nix
│       └── modules.nix
├── LICENSE # License
├── modules
│   ├── configuration # Those modules require options from "nixos" modules to be set, but besides that, they're self contained
│   │   ├── applications # Modules for applications
│   │   │   ├── browser.nix
│   │   │   ├── gaming.nix
│   │   │   ├── programs.nix
│   │   │   └── sudo.nix
│   │   ├── desktop # Modules related to desktop functionality
│   │   │   ├── audio.nix
│   │   │   ├── input.nix
│   │   │   ├── printing.nix
│   │   │   ├── tty.nix
│   │   │   └── wayland.nix
│   │   ├── development # Modules related to development
│   │   │   ├── agents.nix
│   │   │   ├── git.nix
│   │   │   └── IDE.nix
│   │   ├── iso # Modules used exclusively on ISO hosts, related to ISO functionality
│   │   │   ├── default.nix
│   │   │   ├── graphical.nix
│   │   │   └── terminal.nix
│   │   ├── services # Service modules
│   │   │   ├── smart.nix
│   │   │   ├── ssh.nix
│   │   │   ├── sunshine.nix
│   │   │   ├── update.nix
│   │   │   ├── virtualization.nix
│   │   │   └── windows-vm.nix
│   │   ├── system # System modules
│   │   │   ├── bootloader.nix
│   │   │   ├── locale.nix
│   │   │   ├── networking.nix
│   │   │   ├── nix.nix # Nix is a part of the system
│   │   │   ├── power.nix
│   │   │   └── secrets.nix
│   │   ├── _template.nix
│   │   └── user # User modules
│   │       ├── home-manager.nix
│   │       └── xdg.nix
│   └── nixos # Those modules are self contained, but useless without setting their option
│       ├── args # I used special args before, this is legacy name
│       │   ├── hostname.nix
│       │   ├── preservation.nix
│       │   ├── stylix.nix
│       │   └── user.nix
│       ├── desktop-environment # I could've left that out, but I plan to introduce a new DE in the future
│       │   ├── gnome.nix
│       │   ├── options.nix
│       │   └── programs-gnome.nix
│       ├── shell # Shell modules
│       │   ├── nushell.nix
│       │   ├── options.nix
│       │   ├── programs.nix
│       │   ├── secret-programs.nix
│       │   └── zsh.nix # Legacy
│       └── _template.nix
├── packages # My packages
│   ├── docs
│   │   └── default.nix # This package builds the module reference in docs/module-reference.md
│   ├── mirrors # Upstream (me, LOL) doesn't provide caching, so I build them in my CI and push to my cache
│   │   ├── hack
│   │   │   └── default.nix
│   │   └── hexecute-gnome
│   │       └── default.nix
│   ├── shell-scripts # Shell scripts
│   │   ├── rebuild # Faster rebuilds
│   │   │   └── default.nix
│   │   ├── sops-easy # Sops is kinda broken on nixos (or I'm stupid, one of the 2)
│   │   │   └── default.nix
│   │   └── _template
│   │       └── default.nix
│   └── vm-hosts # Run this config in a local VM
│       └── john.nix
├── README.md # README
├── renovate.json
├── REVIEW.md # Review instructions for AI agents
├── secrets
│   └── secrets.yaml # In this file are my secrets. It is encrypted with pq safe age keys
├── SECURITY.md # Github was very annoying about me not having this file, so I added it
└── zensical.toml # Zensical config
```

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
