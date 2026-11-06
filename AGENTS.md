# AGENTS.md

Guidance for agents working in this NixOS configuration flake. Reviewers apply the same rules
through [REVIEW.md](REVIEW.md); the module API is documented in
[lib/modules/README.md](lib/modules/README.md).

## Workflow

1. Inspect the working tree and current branch before editing. Preserve unrelated changes.
   Other sessions may share this checkout; when they do, work in a separate `git worktree`.
2. Start each task on a new branch from the latest `origin/main`, or reuse the task's existing
   branch when continuing its PR. Never include commits from another task's branch.
3. Read the affected files and a nearby example before editing. Keep changes scoped to the task.
4. Commit often: make a small, focused commit after each coherent step instead of one large
   commit at the end. Commit only task-related files.
5. Validate (see [Validation](#validation)), push the branch, and open or update a pull request
   against `main`.
6. Leave merging to the maintainer. Do not merge PRs or enable auto-merge unless explicitly
   asked; the `merge-prs` skill is the sanctioned way to do so when requested.

Never commit or push to `main`. If authentication, network access, or permissions block a push
or PR, keep the work on its branch and report the blocker.

### Naming

- Branches: `<type>(<scope>)/<kebab-description>`, using the commit header without colon or
  spaces. Examples: `docs/refresh-agent-guidance`, `feat(modules)/add-service`,
  `fix(hosts)/correct-boot-settings`.
- Commits follow Conventional Commits: `<type>(<scope>): <imperative lowercase description>`
  with no trailing period. Common scopes: `hosts`, `modules`, `home`, `pkgs`, `lib`, `flake`.
  Documentation-only commits may use `docs: <description>`.
- PRs use `.github/pull_request_template.md`. Describe the resulting behavior, validation run,
  documentation changes, and checks that could not run. Never tick an item that was not verified.

## Repository map

| Path | Purpose |
| --- | --- |
| `flake.nix`, `flake.lock` | Inputs, supported systems, and registry wiring |
| `modules/<name>/` | Module declarations with their packages, checks, and companion sources |
| `modules/host-<name>/` | Host-specific hardware, disks, and other configuration |
| `hosts/*.nix` | Automatically discovered host declarations |
| `arguments/` | Shared typed argument declarations and defaults |
| `lib/modules/` | modules-v3 library: discovery, constructors, argument binding, tests |
| `deploy/` | deploy-rs nodes and their `rebuild-<node>` apps |
| `github-actions/`, `.github/` | CI output matrices, workflows, and policy |
| `docs/`, `zensical.toml` | Documentation site |
| `secrets/`, `.sops.yaml` | Encrypted secrets and age recipient rules |
| `devenv.nix`, `devenv.yaml`, `.devcontainer/` | Development environment and Git hooks |
| `.agents/skills/` | Agent skills; `.claude/skills` links here |

Templates: `modules/_template/` and `hosts/_template.nix`.

## Modules and hosts

### Discovery and selection

- Discovery recursively loads regular `.nix` files under `modules/`, `hosts/`, and `arguments/`,
  skipping underscore-prefixed files and directories. Put companion Nix sources and fixtures in
  underscore-prefixed paths (for example `_checks/`).
- Each module lives in its own directory and returns one `mkModule` declaration that owns its
  configuration, packages, checks, and documentation.
- A host selects a module exactly when the host includes every one of the module's IDs. No IDs
  are added implicitly. Modules never import other registry declarations or consume their
  package exports; select related modules through host IDs instead.
- Host declarations contain only `name`, `role`, `system`, `ids`, and `args`. Hardware, disks,
  users, and state versions belong in selected modules, not inline imports.

### Arguments

- Request every shared value explicitly as a function parameter, including flake context
  (`inputs`, `self`, `lib`). Do not introduce `custom.*` options.
- Declare common arguments in `arguments/` with a type, description, and optional default. Use
  ordinary optional function parameters for module-specific defaults.
- Precedence: explicit host `args` > function defaults > common defaults. `hostName` comes from
  the host name; never set it in `args`.
- Request system-only arguments in the `nixos` section and home-only arguments in the `home`
  section, so an inactive section imposes no requirements.

### Module shape

Keep NixOS and Home Manager options in their own sections:

```nix
{mkModule, ...}:
mkModule {
  name = "example";
  ids = ["example"];
  state = {
    nixos.directories = ["/var/lib/example"];
    home.directories = [".local/share/example"];
  };
  module = _: {
    nixos = {lib, ...}: {
      # System options.
    };
    home = {pkgs, ...}: {
      home.packages = [pkgs.hello];
    };
  };
}
```

- Generated NixOS configurations embed one Home Manager user. Standalone Home Manager evaluates
  only applicable `home` sections, so shared `home` sections must not require `osConfig`; use a
  declared argument or an optional system-specific context.
- Declare persistent paths in the module's `state` field, never directly in `preservation`
  options. System paths are absolute; home paths are relative to the home directory. The
  `preservation` module applies collected state when `preservationEnable` is true.
- Preserve existing `system.stateVersion` and `homeStateVersion` unless asked to migrate them.

### Packages and checks

- Package and check names get the module's name as a prefix; `default` exports as the module
  name. Exported packages are not installed automatically. A section reaches its own module's
  packages only through the explicitly requested `packages` argument.
- Packages pinning an upstream release declare `passthru.updateScript` using
  `pkgs.nix-update-script` with `--flake`, and keep `version` and hashes as literals in the
  module's Nix file. Update them with `nix run .#update-packages` (see `docs/package-updates.md`).
- Check fixtures supply explicit values instead of borrowing real host settings. KVM-dependent
  checks are exported only on `x86_64-linux`; package and check conditions must match where the
  output actually works.

### Systems and inputs

- Both `x86_64-linux` and `aarch64-linux` stay supported. When changing an integration, read the
  pinned upstream interface, including both the system and home modules of nix-crab.
- Add inputs in `flake.nix` with `inputs.nixpkgs.follows = "nixpkgs"` where supported. Lock a
  changed input with `nix flake update <input>`. Never hand-edit `flake.lock` or update
  unrelated inputs.

## Style

Every new or edited Nix file starts with the license header:

```nix
# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
```

- Format with Alejandra (the flake formatter and devenv Git hook). Format only affected files.
- CI also runs Deadnix and Statix (`statix.toml`); keep new code free of their warnings.
- Use camelCase for new internal attributes and kebab-case for new filenames. Keep established
  exported names (`IDE`, `DE`, `llama-cpp`, `networking-desktop`) and upstream option names.
- Use explicit `lib.*` references; never add a top-level `with lib;`. Aim for lines under
  100 characters.
- Comments explain behavior or constraints, not the agent's reasoning. Keep comments and
  progress updates concise.

## Documentation

- Update documentation when changing options, host setup, or user-visible behavior.
- Keep `docs/` general: concepts, workflows, and conventions. Per-module details and module
  relationships belong in the module's own code or documentation.
- Do not edit `docs/usage.md` unless the user explicitly asks.
- `docs/module-reference.md` is generated from `arguments/` by `modules/module-docs/`. Never
  edit it by hand; after changing common arguments, run `nix run .#module-docs-update`.
- Follow a local `CONVENTIONS.md` if present. Use active voice, simple present tense, headings
  without trailing punctuation, and language-tagged code blocks.

## Validation

Enter the development environment with `devenv shell` (there is no flake `devShell`). It
provides Alejandra, nixd, yamllint, and `flake-check` (`nix flake check --no-build`).

| Change | Validation |
| --- | --- |
| Any | `git diff --check` |
| Nix source | `alejandra <changed-files>` and `flake-check` (`nix flake check --no-build`) |
| Host configuration | Also `nixos-rebuild build --flake .#<host>` when practical |
| Check behavior | Build `.#checks.<system>.<name>` |
| Shared `home` behavior | Evaluate the standalone Home Manager fixtures |
| `lib/modules/` | Run `lib/modules/tests/run.py` |
| Common arguments | Regenerate the module reference |
| Markdown only | Review content and paths; no Nix build needed |

- Do not run `nix flake check --no-build --all-systems`; CI evaluates both systems.
- `--no-build` only evaluates; it does not run VM tests. Say which one you ran.
- Follow `docs/checks.md`: add checks for likely failures that evaluation and builds cannot
  catch, and for regressions found in practice. Do not duplicate upstream tests or write tests
  that merely restate configuration assignments.
- VM checks are module-owned and use `pkgs.testers.runNixOSTest`. Start from a nearby `_checks/`
  fixture and import only the modules the test needs.
- A full `nix flake check` is expensive and may need KVM; CI builds the check, package, and host
  matrices from `github-actions/default.nix`.
- If network access, Nix store permissions, architecture, or virtualization block validation,
  report the exact limitation and what did pass. Never claim success, and never change the lock
  file to hide an environment failure.
- Validate with local builds only. Do not activate or deploy anything unless asked. The
  `rebuild`, `rebuild-switch`, and `rebuild-<node>` helpers build from remote `main`, so they
  never validate a task branch.

## Secrets

- Secrets use sops-nix with age. Edit them only through `sops` or the `sops-easy` helper; never
  commit plaintext secrets or private keys.
- Never show decrypted values in command output, diffs, logs, or PR descriptions.
- Do not change `.sops.yaml` recipients without explicit user confirmation.
- Desktop passwords use sops secret paths and yescrypt hashes. ISO and test fixtures contain
  intentionally public credentials; keep the two separate.
