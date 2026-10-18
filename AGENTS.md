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

This flake uses the modules-v3 library in `lib/modules/`. Read `MIGRATION.md` for the
migration status and validation requirements and `lib/modules/README.md` for the constructor API.

| Path | Purpose |
| --- | --- |
| `flake.nix`, `flake.lock` | Inputs, supported systems, and registry wiring |
| `modules/<name>/` | Module declarations, owned packages, checks, and companion sources |
| `modules/host-<name>/` | Host-specific hardware, disks, and other configuration |
| `hosts/*.nix` | Automatically discovered host declarations |
| `arguments/` | Shared typed argument declarations and defaults |
| `lib/modules/` | Discovery, constructors, argument binding, and focused fixtures |
| `github-actions/`, `.github/` | Output matrices, workflows, and CI policy |
| `docs/`, `zensical.toml` | Documentation and site configuration |
| `secrets/`, `.sops.yaml` | Encrypted secrets and age recipient rules |
| `devenv.nix`, `devenv.yaml` | Development tools and formatting hook |

Read affected files and nearby examples before editing. Keep changes scoped to the task.

## Module and host patterns

- Root discovery recursively loads regular `.nix` files under `modules/`, `hosts/`, and
  `arguments/`. Underscore-prefixed files and directories are excluded. Keep companion Nix
  sources and fixtures in underscore-prefixed files or directories.
- Each module has its own directory and returns a `mkModule` declaration. It owns its
  configuration, packages, checks, and documentation. Templates are `modules/_template/`
  and `hosts/_template.nix`.
- A host selects a module exactly when it includes every module ID. No IDs are added
  automatically, and modules do not import other registry declarations or consume their
  package exports. Select related declarations through appropriate host IDs.
- Request shared values explicitly in function parameters. Define common arguments in
  `arguments/` with types, descriptions, and optional defaults. Use ordinary optional
  function parameters for module-specific defaults. Do not introduce `custom.*` options.
- Explicit host arguments override function defaults, which override common defaults.
  `hostName` comes from the host name; never supply it in `args`.
- Request flake context (`inputs`, `self`, `lib`) explicitly. Put system-only arguments in
  `nixos` and home-only arguments in `home` so inactive sections impose no requirements.
- Keep upstream NixOS and Home Manager options in their own section contexts. Use this shape:

```nix
{mkModule, ...}:
mkModule {
  name = "example";
  ids = ["example"];
  module = _: {
    nixos = {lib, preservationEnable, ...}: {
      # System options and guarded /persist state.
    };
    home = {pkgs, ...}: {
      home.packages = [pkgs.hello];
    };
  };
}
```

- Generated NixOS modules embed one Home Manager user and own its integration. Standalone
  Home Manager evaluates only applicable home sections. Avoid requiring `osConfig` in a
  shared home section; use a declared argument or an optional system-specific context.
- Host declarations contain only `name`, `role`, `system`, `ids`, and `args`. Hardware,
  disks, users, and state versions belong in selected declarations, not inline host imports.
- Preserve existing `system.stateVersion` and `homeStateVersion` unless asked to migrate them.
- Guard preservation with `lib.mkIf preservationEnable`. System paths go under `"/persist"`;
  home-relative paths go under `users.${userName}`.
- Package and check names receive the declaring module's prefix; `default` exports as the
  module name. Package exports do not install themselves. Sections access only their own
  packages through the explicitly requested `packages` argument.
- Check fixtures supply explicit values rather than borrowing real host settings. Gate
  KVM-dependent checks to `x86_64-linux`; package/check conditions determine output availability.
- Both supported systems remain `x86_64-linux` and `aarch64-linux`. Inspect pinned upstream
  interfaces when changing integrations, including both nix-crab system and home modules.
- Add dependencies in `flake.nix`, following `inputs.nixpkgs.follows = "nixpkgs"` where
  supported. Run `nix flake update <input>` for an input change; never hand-edit `flake.lock`
  or update unrelated inputs.

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
- `docs/module-reference.md` is generated from `arguments/`, not a hand-maintained module
  index. Never edit it manually. After relevant option changes, run:

```bash
nix run .#module-docs-update
nix build .#checks.x86_64-linux.module-docs
```

The generator and freshness check are defined in `modules/module-docs/default.nix`.

## Development and validation

The development environment uses devenv, rather than a flake `devShell`:

```bash
devenv shell
```

It provides Alejandra, nixd, yamllint, and `flake-check`, which runs `nix flake check --no-build`.

| Change | Validation |
| --- | --- |
| Nix source | `alejandra <changed-files>` and `nix flake check --no-build --all-systems` |
| Host configuration | Also build the affected host with `nixos-rebuild build --flake .#<host>` when practical |
| Check behavior | Build the relevant `.#checks.<system>.<name>` derivation |
| Common argument documentation | Regenerate the reference and build the `module-docs` check |
| Markdown only | Review content, file paths, and `git diff --check`; no Nix build is required |

- `--no-build` checks evaluation; it does not execute VM tests. Report the distinction accurately.
- Follow `docs/checks.md`: add meaningful checks for likely failure modes evaluation/builds cannot
  catch, and regressions discovered in practice. Do not duplicate upstream tests or create tests
  that merely mirror configuration assignments.
- VM checks use module-owned `checks` and `pkgs.testers.runNixOSTest`. Start from a nearby
  `_checks/` fixture; import the modules and dependencies actually required by the test.
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
