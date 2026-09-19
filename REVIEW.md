# REVIEW.md

This is the code review standard for this repository. If you are reviewing as an AI (or human), you are expected to be **harsh, pedantic, and exhaustive**. Do not be nice. Do not leave a thing.

A "looks good to me" that missed a real issue is a failed review.

## 0. Mindset

- **Assume the author is wrong.** Prove correctness, don't assume it.
- **Nitpick on purpose.** Style (except line length/case), docs, and commit hygiene are blocking here. Line length and `camelCase`/`kebab-case` are NIT-only — never block on them.
- **Evidence over opinion.** If you claim it works, cite evaluation (`nix flake check`, `alejandra --check`, built config, or source line `path:line`).
- **If uncertain, request changes.** Do not resolve a thread by guessing.
- **Reject hand-waving.** "It should work" / "upstream handles it" / "will fix later" = request changes.
- **No drive-by approvals.** Every approval must show which checks you actually ran.

## 1. Mandatory Verification

Run before commenting, and paste results or state what you checked. No verification = no approval.

```bash
alejandra --check .          # must pass, no diff
nix flake check --no-build   # must pass (fast check, see devenv.nix:14 flake-check)
# if touching hosts/modules:
nix flake show               # hosts and nixosModules still exported?
git diff --check             # no whitespace errors
rg -n "with lib;" --glob "*.nix"  # must be empty (AGENTS.md bans it)
rg -n "TODO|FIXME|HACK|XXX"       # must be justified or removed
```

If you touch secrets/docs/shell-scripts, also:

```bash
yamllint .sops.yaml
sops --decrypt secrets/secrets.yaml > /dev/null  # no plaintext committed? check git diff
nix run .#rebuild -- --help 2>&1 | head -n 50     # or perSystem package builds
```

CI reference: `.github/workflows/flake-check.yaml:48` runs `deadnix --edit`, `statix fix`, `alejandra`, then `nix flake check --no-build` with `aarch64-linux` via QEMU. Your local review must be at least that strict.

## 2. Severity

Use this explicitly:

- **BLOCKER** — must fix before merge. Eval breaks, secret risk, undocumented behavior, missing check for new functionality (see 3.K).
- **MAJOR** — likely to cause breakage or maintenance pain. Fix or justify with evidence.
- **MINOR / NIT** — still comment. Do **not** block on line length or `camelCase`/`kebab-case` naming — flag as NIT at most.

Do not batch 10 issues into one vague comment. One issue = one thread, with file and line.

## 3. Checklist — Leave No Thing

Go top-down through every section. If a section does not apply, say why.

### A. Flake wiring (`flake.nix:85`)

- [ ] `inputs.*.follows` correct? Every `inputs.nixpkgs.follows = "nixpkgs"` that should follow does, no stale pin.
- [ ] No manual `flake.lock` edits — `nix flake update` only (`AGENTS.md`).
- [ ] `systems` list intentional? `flake.nix:87` lists `x86_64-linux` + `aarch64-linux`; new packages/checks handle both?
- [ ] `imports` in `flake.nix:93` still uses `import-tree` for `modules`, `packages`, `checks`, `github-actions` and `import-tree.match ".*/[^/]+/default\\.nix" ./hosts`? A new host using `_default.nix` must NOT be auto-exported (see `hosts/template/_default.nix`).
- [ ] No unused inputs. If you add an input, you actually use it in a module or package.

### B. Hosts (`hosts/*`)

- [ ] Each host defines `let Hostname = "..."; in { flake.nixosConfigurations.${Hostname} = ... }` (`hosts/armin/default.nix:11` pattern). Hostname string matches directory name? `system` correct (`aarch64-linux` if needed)?
- [ ] `_module.args.hostName = Hostname` present in `modules` list? And `custom.hostname = hostName` set via `hosts/common/desktop-modules.nix:30` or host `modules.nix`? No legacy `hostname` specialArg (`AGENTS.md` hostname convention).
- [ ] `specialArgs = { inherit self inputs; }` — no extra leaking, no `hostname` specialArg reintroduced.
- [ ] `modules` list: only `self.nixosModules.<name>` + `./modules.nix` + `./hardware.nix` (+ `inputs.home-manager.nixosModules.home-manager` with `useGlobalPkgs/useUserPackages/extraSpecialArgs`). Order sane? No duplicate/contradictory modules.
- [ ] `hardware.nix` / `disko.nix` / `facter.json` consistent? `disko` config matches `hardware.nix` imports from `inputs.nixos-hardware.nixosModules.*`? `systemStateVersion` set to NEXT release (see `docs/host-creation-guide.md`)?
- [ ] ISO hosts (`wall-e`, `john`) also export `flake.packages.<system>.<name> = config.system.build.isoImage` (`hosts/wall-e/default.nix:44`, `hosts/john/default.nix:46`). If broken, ISO won't build.
- [ ] `hosts/common/desktop-modules.nix:4` and `hosts/common/iso-modules.nix` not silently diverged — desktop hosts still import `common` correctly; check `hosts/armin/modules.nix:4`.
- [ ] No host-specific hacks that belong in a reusable module. If copy-pasted across `armin`/`victim`, extract to `modules/configuration/`.

### C. Modules (`modules/nixos` vs `modules/configuration`)

- [ ] Correct layer? `modules/nixos/args/*` defines `options.custom.*` (option layer, `lib.mkOption` with `type`, `default`, `example`, `description` — see `modules/nixos/args/hostname.nix:14`); `modules/configuration/*` implements (`config.custom.*` consumer, `preservation.preserveAt`, `home-manager.users.${config.custom.user.name}` — see `modules/configuration/_template.nix:11`).
- [ ] Every `options.custom.*` has type, default, example, description. No `mkOption` without description. No `lib.types.anything` without justification.
- [ ] Module exposes `flake.nixosModules.<name>` — name matches file intent and is documented in `docs/modules.md`/`docs/module-reference.md` if user-facing. `AGENTS.md` prefers `camelCase` attributes / `kebab-case` files, but **do not block** on case — at most a NIT.
- [ ] Takes `inputs` only when needed (`modules/nixos/args/hostname.nix:4` vs `modules/configuration/_template.nix:4` pattern). No `{ inputs, ... }:` if unused.
- [ ] No `with lib;` at top level. Explicit `lib.` prefix (`AGENTS.md`).
- [ ] Conditional logic uses `lib.mkIf` / `lib.mkMerge` / `lib.mkDefault` correctly. No unconditional override that clobbers host config. `lib.mkDefault` for shared defaults like `hosts/common/desktop-modules.nix:34`.
- [ ] `imports = [ inputs.preservation.nixosModules.preservation ]` etc. only inside the inner NixOS module, not at flake level, unless intended.
- [ ] Home-manager wiring inside NixOS module is correct: `home-manager.users.${config.custom.user.name}` — does it handle `config.custom.user.enable` guard? No hard-coded username (`nixi`) inside reusable modules except `desktop-modules.nix:27` which is the shared host base — call it out if leaking.
- [ ] Preservation lists (`/persist` dirs/files) reviewed: no missing `/var/lib` subdirs, no over-persisting secrets, user vs system scope correct.

### D. Nix correctness and hygiene

- [ ] `alejandra .` passes, no `nixpkgs-fmt` mix. **Do not enforce line length** — `AGENTS.md` says lines SHOULD NOT exceed 100 chars, but per `REVIEW.md` do not block on it; flag as NIT only if it hurts readability.
- [ ] Every `.nix` starts with SPDX header (`AGENTS.md`):
  ```nix
  # SPDX-FileCopyrightText: 2026 first-uninteresting-username
  #
  # SPDX-License-Identifier: GPL-3.0-or-later
  ```
- [ ] No `deadnix` findings (unused args: `pkgs`, `lib`, `config`, `inputs`, `self`). CI runs `deadnix --edit` excluding templates (`flake-check.yaml:50`). If you left `...` but unused, `deadnix` will flag `args`.
- [ ] No `statix` warnings (unnecessary `with`, eta, etc.). CI runs `statix fix` (`flake-check.yaml:60`).
- [ ] No `nix` anti-patterns: `builtins.*` without need, `import <nixpkgs>` instead of `inputs.nixpkgs`, string-interpolated paths, `__toString`.
- [ ] Eval is cheap: no `import` of large JSON at eval time, no IFD (`import (fetchTarball ...)`), no unbounded `builtins.readDir`.

### E. Security and secrets (`secrets/`, `.sops.yaml`, `modules/configuration/system/secrets.nix`)

- [ ] **No plaintext secrets in diff.** `rg -n "BEGIN.*PRIVATE|password|token|secret"` — if hit, BLOCKER. Check `git diff --cached` and commit history.
- [ ] No `.sops.yaml` key churn without user confirmation (`AGENTS.md`). New host age key derived via `sudo ssh-to-age -private-key -i /etc/ssh/ssh_host_ed25519_key` (`AGENTS.md`), added to `keys:` + `creation_rules:` (` .sops.yaml:13`).
- [ ] Editing uses `sops secrets/secrets.yaml` or `sops --encrypt --in-place` — not manual `age` encrypt. `sudo sops-easy` if needed (`AGENTS.md`).
- [ ] User password hash is `mkpasswd -m yescrypt`, consumed via `custom.user.hashedPasswordFile = config.sops.secrets."sudo_password/${config.custom.hostname}".path` (`hosts/common/desktop-modules.nix:28`). No `hashedPassword = "..."` literal.
- [ ] `neededForUsers = true` on password secrets (`hosts/common/desktop-modules.nix:20`) if used for login. Check `preservation` doesn't accidentally persist raw `key.txt` (`/var/lib/sops-nix/key.txt`).
- [ ] SSH: no `PermitRootLogin yes`, no `PasswordAuthentication yes` unless ISO debug (`ssh/ssh-debug`). `services.openssh` hardened? Check `modules/configuration/services/ssh.nix`.
- [ ] No world-readable `secrets.yaml` or committed `facter.json` with sensitive serials? `facter.json` is okay but skim for leaked keys.

### F. System and services

- [ ] Bootloader, networking, locale, power, printing, audio/wayland/input/tty blocks reviewed (`modules/configuration/system/*`, `desktop/*`, `services/*`). No conflicting `networking.*` between `networking-desktop` vs `networking-minimal` (ISO).
- [ ] `services` (smart, ssh, sunshine, virtualization, update) — `enable` guards, no open ports without firewall comment, no `virtualisation.*` that breaks `preservation`.
- [ ] `nix` settings (`modules/configuration/system/nix.nix`): `experimental-features`, `gc`, `optimise`, `registry` (`flake-registry` input) sane.
- [ ] Stylix / GNOME / shells: `custom.stylix.image.width/height` strings? (`hosts/common/desktop-modules.nix:34` uses `lib.mkDefault "2560"` — is string correct type?). `custom.shell.name = "nushell"` vs `zsh` — both modules not enabled simultaneously.

### G. Packages, checks, GitHub Actions

- [ ] `packages/` — each `default.nix` follows `perSystem = { pkgs, ... }: { packages.<name> = ... }` (`packages/shell-scripts/rebuild/default.nix:4`). Uses `pkgs.writeShellApplication` with `runtimeInputs`, not bare `writeScript`.
- [ ] `mirrors` packages (`hack`, `hexecute-gnome`) — `flake-registry` etc. not duplicated inputs? Follow `nixpkgs` where possible.
- [ ] `checks/` — philosophy in `docs/checks.md:7` (only add if flake check wouldn't catch). New check justified? Listed in `github-actions/default.nix` if needed.
- [ ] `github-actions/` + `.github/workflows/*` — `nix-github-actions` wiring updated? Workflows pin actions by SHA (`flake-check.yaml:27`), use `DeterminateSystems/nix-installer-action`, `cachix-action`, respect `.github/nix.conf`. No `pull_request_target` without careful `persist-credentials: false`.

### H. Documentation (`docs/`, `README.md`, `AGENTS.md`, `zensical.toml`)

- [ ] Docs follow simple present, active voice, no trailing punctuation on headings, code in highlighted blocks, Prettier formatted (`AGENTS.md`, `zensical.toml:11` `content.code.copy`).
- [ ] Links not broken: `hosts/armin/README.md`, `docs/host-names.md`, `docs/modules.md`, `docs/host-creation-guide.md`. `README.md:24` Hosts Matrix still lists current hosts (`armin`, `victim`, `wall-e`, `john`, `template`) — no resurrected `iroh` (`AGENTS.md` note).
- [ ] `docs/module-reference.md` / `docs/modules.md` updated when adding/renaming `nixosModules`.
- [ ] `zensical.toml` site_name/url/repo_url still correct if repo moved.

### I. Devenv and editor

- [ ] `devenv.nix:4` still provides `yamllint`, `alejandra`, `nixd`; `devenv.yaml:5` inputs follow `nixpkgs`. `files.".vscode/settings.json"` / `files.".zed/settings.json"` still wire `nixd` + `alejandra` (`devenv.nix:18`). No `devShells` reintroduced (`AGENTS.md` says devenv, not devShells).
- [ ] `git-hooks.hooks.alejandra.enable = true` (`devenv.nix:54`) still on — don't bypass with `--no-verify` without reason.

### J. Git hygiene

- [ ] Commits follow Conventional Commits (`AGENTS.md`): `<type>(<scope>): <short description>` — types `feat|fix|docs|style|refactor|perf|test|chore|revert`, scopes `hosts|modules|home|pkgs|lib|flake`, imperative, lowercase, no period, no verb past tense.
- [ ] `git log --oneline -10` clean — no `fixup!`, no `WIP`, no `merge` noise unless intentional. Each commit builds (`nix flake check --no-build` per commit if you can).
- [ ] `git status` / `git diff` — only intended files staged, no stray `result` symlink (`gitignore` should cover), no `facter.json` churn, no `flake.lock` manual edit.
- [ ] PR matches `.github/pull_request_template.md:7` checklist: style, `nix flake check` passes, docs updated, Conventional Commits, secrets encrypted. Description has `fixes #` if closing issues.

### K. Checks for new functionality (required)

- [ ] **New functionality has a check.** If the PR adds a new module, option, package, host, or service, is there a corresponding `checks/` derivation that would catch regressions? Per `docs/checks.md:7`, checks are expected when (a) something broke before that `nix flake check` wouldn't catch, or (b) the change is risky and `nix flake check --no-build` is insufficient. Treat missing check as **BLOCKER** unless the author justifies why `nix flake check` alone is sufficient.
- [ ] Check is actually wired: lives under `checks/` (via `import-tree`), runs in `nix flake check`, and ideally in `github-actions/`. No dead check file that is never imported.
- [ ] Check is meaningful: reproduces the new behavior, not just `true`. Review the check derivation — does it import the new module/host and assert evaluation or build?

## 4. Zero Tolerance — Instant Request Changes

- Missing SPDX header on any `.nix`.
- `with lib;` at top level.
- `alejandra` diff or `nix flake check --no-build` failure.
- Plaintext secret or `.sops.yaml` key change without confirmation.
- Host without `_module.args.hostName` / `custom.hostname` wiring.
- New `flake.lock` diff that is hand-edited JSON (not `nix flake update`).
- `hosts/` new host still using `_default.nix` name (won't be exported by `import-tree.match`).
- Docs heading ends with punctuation or code not in fenced block.
- New functionality with no check and no justification (see 3.K).

## 5. How to Comment

- Be specific: `path:line — BLOCKER: why, what to do, example fix`.
- Quote the offending snippet. Suggest the exact replacement.
- Separate fact from opinion: "BLOCKER (AGENTS.md: code standards)" vs "SUGGESTION (style)".
- If you ran a command, paste the output. If you didn't, say "did not verify — needs check".
- Approve only with: `Verified: alejandra --check ✓, nix flake check --no-build ✓, reviewed: flake/hosts/modules/secrets/docs/git` + any caveats.

Example:

> `modules/configuration/system/nix.nix:22 — BLOCKER: `with lib;` banned by AGENTS.md. Replace with explicit `lib.mkIf`. Verified via `rg -n "with lib;"`.`

## 6. Approval Criteria

Do not approve unless ALL true:

- [ ] All BLOCKERs resolved or acknowledged with follow-up issue.
- [ ] `alejandra --check` and `nix flake check --no-build` would pass (or you actually ran them).
- [ ] No secrets risk, no eval break, no host fails to build (`nixos-rebuild build --flake .#<host>` for touched hosts if feasible).
- [ ] Docs and `AGENTS.md` updated if behavior changed; host matrix / module docs not stale.
- [ ] Commits are Conventional Commits and PR checklist is truthful.

Be harsh now so `main` stays green and maintainable. If it's borderline, request changes.
