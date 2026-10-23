# Review guidance

Review changes against [AGENTS.md](AGENTS.md), the [module API](lib/modules/README.md),
and the [checks policy](docs/checks.md). Investigate correctness, integration, security,
documentation, and validation evidence. Report actionable findings with a file, line,
concrete failure scenario, and suggested correction. Separate verified facts from assumptions.

## Validation evidence

Run checks appropriate to the changed files and state exactly what passed, failed, or could
not run. For Markdown-only changes, review content and paths and run `git diff --check`.
For Nix changes, format affected files and evaluate both supported systems:

```bash
alejandra --check <changed-nix-files>
nix flake check --no-build --all-systems
git diff --check
```

Basic CI also runs Deadnix, Statix, Python CI-policy tests, and Node branch-policy tests.
Selected library evaluation jobs run `lib/modules/tests/run.py --diagnostics-only --system <system>`.
CI checks formatting and lints without modifying files;
intentional placeholders in the host and module templates are excluded from lint checks.

Evaluation does not run VM tests. Build affected packages, documentation, and behavioral
checks when relevant. Build changed hosts with `nixos-rebuild build --flake .#<host>` when
practical. Use the standalone Home Manager fixtures when shared home behavior changes.
Report network, Nix store, architecture, and KVM limitations precisely. An environmental
failure does not prove a behavioral assertion ran. Never activate a configuration or run
the `rebuild` helper for validation; that helper boots remote `main`.

## Flake and discovery

- [ ] Both `x86_64-linux` and `aarch64-linux` remain supported. Package and check conditions
  match their actual availability; KVM checks are exported only on x86_64-linux.
- [ ] Inputs follow the pinned Nixpkgs where supported. Input updates use
  `nix flake update <input>` without unrelated lock changes or manual lock edits.
- [ ] Root discovery loads regular `.nix` files recursively from `modules/`, `hosts/`, and
  `arguments/`. Companion Nix sources and fixtures use underscore-prefixed paths.
- [ ] Module, host, argument, and final package/check export names remain unique.
  `flake.nix` takes its outputs from registry discovery. `github-actions/` only derives CI
  matrices and the opt-in regression outputs from the registry; it does not replace discovery.

## Hosts and arguments

- [ ] Hosts contain only `name`, `role`, `system`, `ids`, and `args`. Hardware, disks,
  users, and state versions live in selected module declarations.
- [ ] Selection requires every module ID to occur in the host. Related IDs are explicit;
  modules do not import registry declarations or add dependencies automatically.
- [ ] `hostName` derives from the host name and does not appear in `args`. Unknown argument
  names fail, and warnings about unused known arguments are investigated.
- [ ] Common arguments in `arguments/` have types, descriptions, and optional defaults.
  Explicit host values override ordinary function defaults, then common defaults.
- [ ] Existing `system.stateVersion` and `homeStateVersion` remain unchanged unless the
  task explicitly requests a migration. Hardware and disk sources match the intended host.
- [ ] ISO package exports remain `host-john` and `host-wall-e`; their boot smoke checks
  remain `iso-john` and `iso-wall-e` in the separate ISO tier.

## Modules and packages

- [ ] Each module owns its configuration, packages, checks, and documentation through
  `mkModule`. Shared settings use declared arguments instead of `custom.*` options.
- [ ] Functions explicitly request arguments and context such as `inputs`, `self`, and
  `lib`. System-only requirements stay in `nixos`; home-only requirements stay in `home`.
- [ ] Upstream NixOS and Home Manager options use their respective section contexts.
  Standalone Home Manager omits NixOS-only configuration, arguments, and assertions.
- [ ] Generated modules own Home Manager integration and embed one user. Shared home
  sections avoid requiring `osConfig`; direct consumers supply declared arguments through
  `specialArgs` or `extraSpecialArgs` as described in the library API.
- [ ] Applicable assertions use the ordinary assertion/message shape and fail evaluation.
- [ ] Preservation uses `lib.mkIf preservationEnable`. System paths belong under
  `"/persist"`; home-relative paths belong under `users.${userName}`.
- [ ] Modules use only their own package exports through the requested `packages` context.
  Exports do not install themselves. Host-dependent construction stays in local lambdas.
- [ ] `default` exports as the module name; other packages and checks export as
  `<module>-<name>`. Output names and consumers agree after renames.
- [ ] Edited Nix files have the repository SPDX header and Alejandra formatting. Use explicit
  `lib.*` references and avoid a top-level `with lib;`. Flag line length and naming as minor
  issues unless they cause a concrete correctness problem.

## Checks and CI

- [ ] Meaningful checks cover likely integration failures and regressions that evaluation
  or builds cannot catch. Do not require checks that repeat assignments or upstream tests.
- [ ] Checks belong to their module and use explicit disposable fixture values. Start from
  a nearby `_checks/` fixture and exercise the actual production module.
- [ ] Generated ownership metadata matches exported targets on both systems. Module-directory
  changes select all owned checks and packages; unrelated modules never select those checks.
- [ ] Selection compares complete merge-base/head diffs and metadata, including deletions,
  renames, moved declarations, removed outputs, and deliberately empty selections.
- [ ] Only the explicit core-infrastructure list selects the full non-ISO suite. Scheduled/manual
  full validation, host builds, ISO tests, caching, diagnostics, and failure logs remain available.
- [ ] The required `all-systems-passed` aggregate fails on discovery failures and unexpected
  skips. Only explicitly empty selections skip their build tier.
- [ ] Intentional regressions stay outside normal checks. Proof runs first pass the positive
  control, then detect the intended assertion failure rather than a fetch or setup error.
- [ ] Workflow actions are pinned by SHA. Untrusted PR code does not receive write credentials;
  merge policy verifies trusted identities and the current immutable head revision.

## Security and system behavior

- [ ] Diffs and logs contain no plaintext secrets or private keys. Inspect relevant changes
  without printing decrypted values. Edit encrypted secrets through `sops` or `sops-easy`.
- [ ] `.sops.yaml` recipients change only with explicit user confirmation. Desktop password
  secrets retain yescrypt hashes, correct secret paths, and user-creation ordering.
  Public ISO/test credentials remain distinct from desktop credentials.
- [ ] Services preserve intended enable guards, firewall behavior, startup ordering, and
  persistent state. Review boot, network, desktop, and update behavior where affected.

## Documentation and delivery

- [ ] User-facing changes update relevant guidance in active voice with language-tagged
  code blocks and headings without trailing punctuation. Verify changed local links.
- [ ] `docs/module-reference.md` is generated from common arguments; regenerate it after relevant
  changes. Do not edit it manually or change `docs/usage.md` without an explicit request.
- [ ] Every host installs local documentation. Selected content, alphabetical imperative
  steps, `open-docs` in Lynx, and the desktop entry remain usable without a web server.
  Documentation never includes secret values or executes imperative steps.
- [ ] Development tools remain in devenv, including the Alejandra commit hook.
- [ ] Commits follow Conventional Commits and include only task-related files. Continue the
  task PR or create its dedicated branch; never commit or push directly to `main`.
- [ ] The PR follows the repository template and describes resulting behavior, validation,
  documentation, and limitations truthfully. Leave merging and deployment to the maintainer.

## Findings and approval

Prioritize correctness, security, and observable regressions. Treat evaluation failures,
secret exposure, broken host behavior, and missing necessary regression coverage as blockers.
Explain lesser maintenance or style findings proportionately. Give each finding its own
location and failure scenario instead of batching unrelated issues.

Approve only after reviewing the affected contracts and recording checks actually performed.
Do not claim that unrun builds or VM tests pass. If evidence is missing, name the unresolved
validation and its consequence so the maintainer can decide how to proceed.
