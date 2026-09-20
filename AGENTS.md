# AGENTS.md

Guidance for AI assistants working in this repository.

## Project Overview

Flake-based NixOS configuration using [flake-parts](https://github.com/hercules-ci/flake-parts) and [import-tree](https://github.com/vic/import-tree). Hosts are defined under `hosts/` and compose reusable modules from `self.nixosModules`.

## Repository Structure

```
.
├── flake.nix            # Flake entry point (flake-parts + import-tree)
├── hosts/               # One subdir per host, each with default.nix defining nixosConfigurations.<name>
│   ├── armin/           # Desktop (Framework 13, GNOME)
│   ├── victim/          # Desktop (Gigabyte B650, GNOME)
│   ├── wall-e/          # Minimal ISO (terminal)
│   ├── john/            # Graphical ISO
│   ├── template/        # Starter template (_default.nix) — copy to create a new host
│   └── common/          # Shared host logic (e.g. desktop-modules.nix)
├── modules/
│   ├── configuration/   # Reusable NixOS modules -> flake.nixosModules.<name>
│   │   ├── applications/ desktop/ development/ iso/ services/ system/ user/
│   │   └── _template.nix
│   └── nixos/           # Flake-level plumbing -> flake.nixosModules.<name>
│       ├── args/        # custom.* options (hostname, user, preservation, stylix)
│       ├── desktop-envinroment/
│       ├── server/  shell/
│       └── _template.nix
├── packages/            # perSystem packages (import-tree)
│   ├── mirrors/  shell-scripts/  # rebuild, sops-easy, template, etc.
│   └── docs/
├── checks/              # flake checks (import-tree)
├── github-actions/      # nix-github-actions wiring (import-tree)
├── secrets/             # sops-nix encrypted secrets (age)
├── docs/                # User-facing documentation
├── devenv.nix / devenv.yaml
├── .sops.yaml
└── zensical.toml
```

## Architecture

### Flake Wiring

`flake.nix:85` uses `import-tree`:

```nix
imports = [
  (inputs.import-tree ./modules)
  (inputs.import-tree ./packages)
  (inputs.import-tree ./checks)
  (inputs.import-tree ./github-actions)
  (inputs.import-tree.match ".*/[^/]+/default\\.nix" ./hosts)
];
```

- `modules/`, `packages/`, `checks/`, `github-actions/` — recursive import, every `default.nix` contributes outputs.
- `hosts/` — only `*/default.nix` one level deep is matched. A host that should not be auto-exported uses `_default.nix` (e.g. `hosts/template/_default.nix`).

### Host Definition

Each host's `default.nix` follows `hosts/armin/default.nix:11`:

```nix
let Hostname = "armin"; in {
  flake.nixosConfigurations.${Hostname} = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit self inputs; };
    modules = [
      { _module.args.hostName = Hostname; }
      ./modules.nix
      ./hardware.nix
      self.nixosModules.<name>
      # ...
    ];
  };
}
```

ISO hosts (`wall-e`, `john`) also expose `flake.packages.<system>.<name>` as `config.system.build.isoImage`.

`hosts/common/desktop-modules.nix:4` is the shared desktop base — it imports `self.nixosModules.hostname`, `user`, `stylix`, etc. and sets `custom.hostname = hostName` from `_module.args.hostName`.

### Modules

Two layers, both exposed as `flake.nixosModules.<name>`:

- `modules/nixos/args/` — defines `options.custom.*` consumed via `config.custom.*`. This is the option layer.
- `modules/configuration/` — implements system/home-manager config, typically reading `config.custom.*`.

Hosts opt in by listing `self.nixosModules.<name>` in `default.nix` (system-level) and configuring via `custom.*` in `modules.nix`.

Canonical module shapes:

No flake inputs needed (`modules/configuration/_template.nix:4`):

```nix
_: {
  flake.nixosModules.MODULE_NAME = { lib, config, ... }: {
    # config here, read config.custom.*
  };
}
```

Needs flake inputs (`modules/nixos/args/hostname.nix:4` style):

```nix
{ inputs, ... }: {
  flake.nixosModules.MODULE_NAME = { lib, config, ... }: {
    imports = [ inputs.preservation.nixosModules.preservation ];
  };
}
```

Templates: `modules/configuration/_template.nix` and `modules/nixos/_template.nix`.

## Development Environment

Provided by [devenv](https://devenv.sh/) (`devenv.nix`, `devenv.yaml`), not `devShells`.

```bash
devenv shell   # enter dev shell
direnv allow   # auto-enter via direnv
```

Provides `alejandra` (Nix formatter, also a git-hook), `nixd` (language server), `yamllint`. Editor settings for VS Code/Zed are generated via `files.".vscode/settings.json"` and `files.".zed/settings.json"` in `devenv.nix:18`.

Custom script:

```bash
flake-check  # runs: nix flake check --no-build  (devenv.nix:14)
```

## Code Standards

### File Header

Every `.nix` file MUST start with:

```nix
# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
```

### Nix Style

- Format with `alejandra` (`alejandra .`). Enforced by git-hooks (`devenv.nix:54`).
- Lines SHOULD NOT exceed 100 characters.
- Attribute names MUST be `camelCase`; file names MUST be `kebab-case`.
- NEVER use `with lib;` at top level — use explicit `lib.` prefix.

### Hostname Convention

Do not use a `hostname` specialArg. Instead:

1. Host `default.nix` sets `_module.args.hostName = Hostname` inside `nixosSystem` modules list.
2. Shared or host `modules.nix` sets `custom.hostname = hostName` (where `hostName` comes from `_module.args`).
3. `self.nixosModules.hostname` (`modules/nixos/args/hostname.nix:22`) sets `networking.hostName = config.custom.hostname`.
4. All other modules read `config.custom.hostname`.

Example: `hosts/common/desktop-modules.nix:30`.

### Docs Style

If editing `docs/`, follow `CONVENTIONS.md` when present: simple present tense, active voice, headings without trailing punctuation, code in highlighted blocks, format with Prettier. `zensical.toml` configures the docs site.

## Adding a Host

1. Copy `hosts/template/` to `hosts/<new-host>/` and rename `_default.nix` to `default.nix`.
2. Set `Hostname` in `let` block and `system` if not `x86_64-linux`.
3. Write `disko.nix`, generate `facter.json` with `nixos-facter`, wire `hardware.nix` (see `docs/host-creation-guide.md`).
4. Edit `default.nix` module list (system modules) and `modules.nix` (`custom.*` options). Write host-specific tweaks in `configuration.nix`.
5. See `docs/host-names.md` for naming and `docs/modules.md` for available modules.

## Secrets Handling

Stack: [sops-nix](https://github.com/Mic92/sops-nix) + [age](https://github.com/FiloSottile/age).

Key derivation (age public key from SSH host private key):

```bash
sudo ssh-to-age -private-key -i /etc/ssh/ssh_host_ed25519_key | tail -1
# or
sudo cat /var/lib/sops-nix/key.txt | grep "public key"
```

Edit secrets:

```bash
sudo sops-easy secrets/secrets.yaml
sops --encrypt --in-place secrets/secrets.yaml
```

Adding a secret:

1. Add the host's age key to `.sops.yaml` (`keys:` + `creation_rules:`).
2. Edit `secrets/secrets.yaml` via `sops`.
3. For user passwords use `mkpasswd -m yescrypt` ( `custom.user.hashedPasswordFile` expects yescrypt).

Age keys for `armin`/`victim` are already in `.sops.yaml:13`.

## Commands

| Task             | Command                                                                                                                                            |
| ---------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| Format           | `alejandra .`                                                                                                                                      |
| Fast check       | `flake-check` or `nix flake check --no-build`                                                                                                      |
| Full check       | `nix flake check`                                                                                                                                  |
| Build host       | `nixos-rebuild build --flake .#<hostname>`                                                                                                         |
| Deploy (on host) | `rebuild` — wraps `nh os boot github:first-uninteresting-username/NixOS-config/main#$HOSTNAME` (`packages/shell-scripts/rebuild/default.nix:12`) |
| Edit secrets     | `sops secrets/secrets.yaml`                                                                                                                        |

## Git Conventions

### Commits

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <short description>

[optional body]
```

- Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `revert`
- Scopes: `hosts`, `modules`, `home`, `pkgs`, `lib`, `flake`
- Imperative mood, lowercase, no trailing period.

### Pull Requests

Checklist from `.github/pull_request_template.md`:

- [ ] Code follows style guidelines (alejandra formatted)
- [ ] `nix flake check` passes
- [ ] Documentation updated if needed
- [ ] Commits follow Conventional Commits
- [ ] Secrets are encrypted (no plaintext secrets committed)

## Agent Notes

- Prefer editing existing files over creating new ones. Never add comments as chain-of-thought.
- Verify changes with `nix flake check --no-build` or `alejandra` when touching Nix.
- Do not mutate `flake.lock` manually — use `nix flake update`.
- Do not commit plaintext secrets or modify `.sops.yaml` keys without user confirmation.
- Host `iroh` referenced in older docs no longer exists; current hosts are `armin`, `victim`, `wall-e`, `john`, `template`.
