# AGENTS.md

Guidance for agents working in this NixOS configuration repository.

## Branches and pull requests

- Never commit or push changes directly to `main`.
- Before editing, inspect the working tree and current branch. Preserve unrelated user changes.
- Use a dedicated branch for each task, named `<conventional-commit-header>/<feature-description>`.
  The header is the commit type with an optional scope, without a colon or spaces; the description
  uses kebab-case. Examples: `docs/refresh-agent-guidance`, `feat(modules)/add-service`,
  and `fix(hosts)/correct-boot-settings`.
  Start new work from the latest `origin/main`; reuse an existing task branch when continuing its PR.
  Do not include unrelated commits from another task's branch.
- Validate changes, commit only task-related files, push the task branch, and create a pull request
  targeting `main`. Update the existing PR when continuing the same task.
- Leave merging to the maintainer. Do not merge PRs or enable auto-merge unless explicitly requested.
- If authentication, network access, or permissions prevent pushing or creating a PR, keep the local
  work on its branch and report the blocker. Never fall back to pushing to `main`.
- Follow Conventional Commits: `<type>(<scope>): <imperative lowercase description>` with no trailing
  period. Common scopes are `hosts`, `modules`, `home`, `pkgs`, `lib`, and `flake`; documentation-only
  commits may use `docs: <description>`.
- Use `.github/pull_request_template.md`. Describe the resulting behavior, relevant validation,
  documentation changes, and any checks that could not run. Do not mark an unchecked item as passed.

## Repository map

This is a flake-based configuration built with `flake-parts` and `import-tree`.

| Path | Purpose |
| --- | --- |
| `flake.nix`, `flake.lock` | Inputs, supported systems, import wiring, and pinned dependencies |
| `hosts/armin/`, `hosts/victim/` | Desktop hosts with hardware, disko, and facter configuration |
| `hosts/wall-e/`, `hosts/john/` | Terminal and graphical ISO hosts |
| `hosts/common/` | Shared desktop and ISO module selections and defaults |
| `hosts/template/` | Starter host; `_default.nix` keeps it out of automatic host discovery |
| `modules/configuration/` | Application, desktop, development, ISO, service, system, and user modules |
| `modules/nixos/` | Custom options and implementations for user, hostname, persistence, theme, DE, shell |
| `packages/` | Per-system packages, mirrored inputs, shell tools, VM support, and generated docs |
| `checks/` | NixOS VM checks, graphical checks, and excluded examples |
| `github-actions/` | Flake outputs for CI matrices of checks, packages, and hosts |
| `.github/` | Workflows, repository settings, issue templates, and PR template |
| `docs/`, `zensical.toml` | Documentation and site configuration |
| `secrets/`, `.sops.yaml` | Encrypted secrets and age recipient rules |
| `devenv.nix`, `devenv.yaml` | Development tools, editor settings, and formatting hook |

Read the affected files and nearby examples before making changes. Prefer extending an existing
module over creating a parallel implementation. Keep changes scoped to the requested task.

## Flake and module patterns

- `flake.nix` recursively imports `modules/`, `packages/`, `checks/`, and `github-actions/` through
  `import-tree`. Imported files are flake-parts modules, not necessarily named `default.nix`.
- Hosts use the separate matcher `.*/[^/]+/default\\.nix`. Follow the existing host layout and use
  underscore-prefixed files or directories for templates/examples excluded from automatic imports.
- Outputs support `x86_64-linux` and `aarch64-linux`; current real hosts use `x86_64-linux`.
  Keep per-system packages portable where practical and gate architecture-specific checks explicitly.
- Reusable system modules export `flake.nixosModules.<name>`. One file can export multiple modules;
  inspect its exports rather than assuming a filename equals its module name.
- Take flake inputs in the outer flake-parts function. Take `config`, `lib`, `pkgs`, and other NixOS
  arguments in the inner system module. Follow this shape:

```nix
{inputs, ...}: {
  flake.nixosModules.example = {config, lib, ...}: {
    # System configuration and embedded Home Manager configuration.
  };
}
```

- Use `_: { ... }` for the outer function when no flake arguments are needed. Templates live in
  `modules/configuration/_template.nix` and `modules/nixos/_template.nix`.
- Define reusable options under `options.custom.*` with types, defaults, descriptions, and examples
  where applicable. Use `lib.mkEnableOption`, `lib.mkIf`, and `lib.mkDefault` consistently with nearby
  modules. Read values through `config.custom.*`.
- Hosts opt into modules through `self.nixosModules.*`; their `modules.nix` files select shared
  defaults and customize `custom.*`. Keep hardware and disk layout in the host's hardware files.
- Add dependencies in `flake.nix`, following `inputs.nixpkgs.follows = "nixpkgs"` where supported.
  Update the affected input with `nix flake update <input>`; never hand-edit `flake.lock` or update
  unrelated inputs as part of a focused change.
- Inspect the pinned input's interface when changing integrations. For example, gaming imports
  both the NixOS and Home Manager modules from `nix-crab`; keep those configurations compatible.

## Hosts, Home Manager, and persistence

- Use `hosts/armin/default.nix` as a desktop wiring example and `hosts/template/` for a new host.
  Rename the copied `_default.nix` to `default.nix`, set its `Hostname` and architecture, and supply
  actual hardware, disko, and facter data. See `docs/host-creation-guide.md`.
- Set `_module.args.hostName = Hostname` inside the host's NixOS module list. Shared host modules set
  `custom.hostname = hostName`; the hostname module sets `networking.hostName`. Other modules read
  `config.custom.hostname`. Do not introduce a `hostname` special argument.
- `hosts/common/desktop-modules.nix` enables the user, GNOME, theme, preservation, and shell defaults.
  `hosts/common/iso-modules.nix` supplies the ISO user and disables preservation. Keep reusable
  modules usable in both contexts rather than assuming desktop-only defaults.
- ISO hosts also export their `config.system.build.isoImage` through `flake.packages`.
- User settings live inside system modules at
  `home-manager.users.${config.custom.user.name}`. Inside a Home Manager function, `config` refers
  to home configuration; use `osConfig` for system options when needed.
- Follow the existing Home Manager wiring: global packages, user packages, and required
  `extraSpecialArgs` are configured by the host/module composition.
- Persist state through `preservation.preserveAt`, guarded by
  `lib.mkIf config.custom.preservation.enable`. System paths go under `"/persist"`; home-relative
  paths go under `users.${config.custom.user.name}`. See the configuration template and `llama-cpp`.
- Preserve existing `system.stateVersion` and `home.stateVersion` unless a migration is requested.

## Formatting and documentation

- Do not edit `docs/usage.md` unless the user explicitly requests it.
- Keep progress updates and code comments concise.

Every new or edited Nix file starts with the repository's license header:

```nix
# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
```

- Format Nix with Alejandra, the flake formatter and devenv Git hook. Prefer formatting affected
  files; avoid unrelated repository-wide formatting changes.
- Use camelCase for new internal attributes and kebab-case for new filenames. Preserve established
  exported names such as `IDE`, `DE`, `llama-cpp`, and `networking-desktop`, and upstream option names.
- Use explicit `lib.*` references; do not introduce a top-level `with lib;`. Aim for lines under
  100 characters. Comments explain behavior or constraints, not the agent's reasoning process.
- Update user documentation when changing options, host setup, or user-visible behavior.
  Follow a local `CONVENTIONS.md` if present; use active voice, simple present tense, headings without
  trailing punctuation, and language-tagged code blocks.
- `docs/module-reference.md` is generated from `options.custom.*`, not a hand-maintained module
  index. Never edit it manually. After relevant option changes, run:

```bash
nix run .#update-module-docs
nix build .#checks.x86_64-linux.module-docs
```

The generator and freshness check are defined in `packages/docs/default.nix`.

## Development and validation

The development environment uses devenv, rather than a flake `devShell`:

```bash
devenv shell
```

It provides Alejandra, nixd, yamllint, and `flake-check`, which runs `nix flake check --no-build`.

| Change | Validation |
| --- | --- |
| Nix source | `alejandra <changed-files>` and `nix flake check --no-build` |
| Host configuration | Also build the affected host with `nixos-rebuild build --flake .#<host>` when practical |
| Check behavior | Build the relevant `.#checks.<system>.<name>` derivation |
| Custom option documentation | Regenerate the reference and build the `module-docs` check |
| Markdown only | Review content, file paths, and `git diff --check`; no Nix build is required |

- `--no-build` checks evaluation; it does not execute VM tests. Report the distinction accurately.
- Follow `docs/checks.md`: add meaningful checks for likely failure modes evaluation/builds cannot
  catch, and regressions discovered in practice. Do not duplicate upstream tests or create tests
  that merely mirror configuration assignments.
- VM checks use `perSystem.checks` and `pkgs.testers.runNixOSTest`. Start from a nearby check or
  `checks/_example-checks/`; import the modules and dependencies actually required by the test.
- Full `nix flake check` can be expensive and require virtualization. CI builds matrices of checks,
  packages, and host systems via `github-actions/default.nix`.
- Evaluation may fetch inputs and artifacts, including gaming dependencies. If network access,
  Nix store permissions, or virtualization blocks validation, report the exact limitation and
  completed checks. Do not claim success or modify the lock file to conceal an environment failure.
- Build locally for validation. The `rebuild` helper boots a configuration from remote `main`, so it
  does not validate a task branch. Do not activate or deploy a configuration unless requested.

## Secrets

- Secrets use sops-nix with age. Keep secret files encrypted and edit them through `sops` or the
  existing `sops-easy` helper; never commit plaintext secrets or private keys.
- Do not expose decrypted values in command output, diffs, logs, or PR descriptions.
- Do not change `.sops.yaml` recipient keys without explicit user confirmation.
- Desktop password configuration uses sops secret paths and yescrypt password hashes. Preserve the
  distinction between desktop secrets and the intentionally public credentials in ISO/test fixtures.
