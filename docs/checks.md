# Checks

Behavioral checks target failures that evaluation and package builds cannot detect. Use a
check when an integration is likely to break, or when a regression escaped earlier validation. Test
observable behavior through the repository's real modules and disposable fixtures. Avoid
repeating upstream tests or asserting only that an option has its assigned value.

Behavioral checks and packages belong to their declaring modules. CI uses generated ownership
metadata at the merge base and head revisions to select affected outputs on each supported system.

## Host evaluation tests

Host evaluation tests live in `eval-tests/`, independently of the module registry and its
ownership selection. They read final `nixosConfigurations` options and assert the intended
composition of real hosts. For example, GNOME and GDM must be enabled on victim, armin,
and john, and disabled on wall-e. These tests catch missing host selections and accidental
configuration overrides without building or booting a system.

Run every host evaluation test with:

```bash
nix eval --json .#evalTests
```

Successful tests return named `true` results. A mismatch fails evaluation and identifies
the test, host, option path, expected value, and actual value. Missing hosts or options also
fail evaluation. Add expectations in `eval-tests/hosts.nix` using `host`, an `option` path
list, and `expected`; expectations stay separate from module declarations and host IDs.
Basic CI validation runs the complete set on every run, including module-only changes.
`nix flake check --no-build` alone does not run this separate output. These assertions
complement behavioral VM tests; they do not establish that a desktop session works.

## CI tiers

| Tier | Trigger | Work |
| --- | --- | --- |
| Basic validation | Every PR, pushes to main, and full runs | Reuse **Flake check** for Alejandra, Deadnix, Statix, CI policy tests, and `nix flake check --no-build --all-systems`. |
| Non-ISO packages | Affected module directories in a PR; all on full runs | Build selected exported packages on their supported systems. Shared infrastructure changes select all non-ISO packages. |
| Behavioral tests | Affected files in a PR; complete suite on full runs | Build selected VM tests and the retained documentation freshness check. Any `flake.lock` change selects the complete non-ISO suite. |
| ISO images and smoke tests | **ISO build** on demand | Build john, wall-e, or both at a selected ref and boot the actual exported images. |
| Weekly master check | Thursday at 08:00 UTC on main | Basic validation, all non-ISO packages, the complete test suite, all four hosts, both ISO images, and both ISO smoke tests. |

**Flake build** also supports a manual full run on its selected workflow ref. The exported
`githubActions` matrices come from `github-actions/default.nix`. ISO package identity is
explicit: only `packages.x86_64-linux.host-john` and `packages.x86_64-linux.host-wall-e` move to the
ISO tier. Other package names and systems remain in the ordinary package matrix. Host
discovery preserves armin, victim, john, and wall-e even though they share a system.

For a manual full run, enable `prove-regressions` to build every positive control followed
by its intentional regression. The additional proof tier must succeed when selected and
must be skipped otherwise; the required aggregate validates that choice too.

Builds use `nix-fast-build --skip-cached`. Every selected package stays in its matrix;
a cached output can finish without rebuilding, while an uncached output must build. Cache publication is
optional and only enabled when the run has an authorized Cachix token. Fork PRs and runs
without cache write credentials still build using public substitutes.

Basic validation checks formatting and lints without rewriting the PR. Statix's
`repeated_keys` style warning is disabled in `statix.toml` to allow the established
independent flake exports; other lint checks remain enabled. Host and module templates are
omitted from dead-code/lint validation where intentional placeholders require it. Start new
behavioral checks from a nearby module-owned `_checks/` fixture and declare them in that module
instead of adding flake-parts check declarations under `checks/`. Independent host evaluation
tests live under `eval-tests/`. The remaining `checks/default.nix` only declares the opt-in `regressionChecks` output type.

## Ownership selection

`githubActions.selection` contains the per-system module ownership metadata and exported
package/check matrices. `.github/scripts/select-tests.py` validates their agreement in both
directions, including target names, systems, attributes, duplicate entries, and ISO tiers.
Missing, malformed, or inconsistent metadata fails discovery.

For PRs, discovery evaluates the merge base's snapshot from Git and the head snapshot from
the checked-out PR head. Builds use that same immutable head revision. The selector compares
the complete PR diff against the merge base; NUL-delimited paths and disabled rename detection
retain deleted files and both paths of renames. Selection uses ownership from both revisions,
follows moved modules to their current exports, and reports removed targets without trying
to build nonexistent outputs. A base predating the snapshot selects the complete non-ISO
suite so the initial migration remains covered. Evaluation errors never trigger that fallback.

A change anywhere inside a module directory selects every check and package declared in
that directory. Multiple declarations in one directory share its trigger. A module without
checks adds no behavioral tests merely because it changes; its exported packages still build.
Checks can declare additional literal watched files with `extraFiles`; these select the check,
including when a watched dependency is removed at head. Declare cross-module fixture inputs
there rather than in a central dependency map.
See [Output ownership][output-ownership] for the declaration format.

Lock files, shared libraries, common arguments, host declarations, flake wiring, development
environment files, CI infrastructure, and shared user/Home Manager composition select all
non-ISO checks and packages. Unknown Nix sources outside `modules/` also select the full suite.
Documentation-only changes normally omit both build tiers; the generated common-argument
reference selects its freshness check. The workflow summary lists targets, systems, reasons,
and removed outputs. Base/head snapshots and selected/full-run matrices remain workflow artifacts.

VM tests run on x86_64-linux. Documentation freshness and library/standalone evaluation
fixtures run on both supported systems. Packages follow their per-system export availability.
The `iso-` checks and explicit ISO packages remain in the separate ISO tier, including after
lock-file changes. Scheduled/manual full runs still build every ordinary package and check,
all four hosts, both ISO images, and both smoke checks. An ordinary PR can explicitly omit
an empty package or check selection.

## Required status and logs

Keep **all-systems-passed** as the stable required branch-protection status. It requires
basic validation and discovery to succeed. Selected package and test tiers must succeed;
only an explicitly empty selection may produce a skipped package or test job. Host and ISO jobs
must be skipped on ordinary PRs and succeed on full runs. Missing, failed, cancelled,
pending, or unexpectedly skipped required tiers fail the aggregate.

Superseded PR runs are cancelled. Build and validation failures upload logs for 14 days;
GitHub also retains runner logs. Weekly failures create or update the `ci-failure` issue
with links to failed jobs. Test-selection matrices are retained as workflow artifacts.

## Behavioral coverage and check audit

The previous VM checks are removed from the default suite. These replacements each catch
a distinct integration failure:

| Previous check | Replacement and observable failure mode |
| --- | --- |
| `networking` | `networking-desktop-secrets` uses the actual secret-backed desktop networking module and disposable encrypted sops data; checks keyfile contents, root ownership, 0600 permissions, and profiles loaded by NetworkManager. It catches missing secret-service ordering and a failed profile reload. |
| `gnome-minimal`, `john`, `wayland` | `GNOME-session` starts an actual GNOME Wayland user session, opens the configured terminal, and checks Home Manager activation. Starting a display-manager unit or running `wl-copy --version` alone cannot establish a usable session. |
| `update` | `update` runs the actual service with a local recording `nixos-rebuild` substitute. It checks the boot command, selected hostname/flake, environment, and propagation of a nonzero exit status. It never upgrades from remote main. |
| `printing` | `printing-discovery` resolves a real independent DNS-SD printer announcement from a client, resolves its mDNS hostname, and verifies that CUPS accepts loopback clients while rejecting access through the desktop network address and from a peer. |
| No previous equivalent | `preservation-persistence` reboots a VM with tmpfs root and a disposable persistence disk. User/system state, machine ID, and SSH identities survive; unpreserved state disappears. |
| No actual-image equivalent | `iso-john` and `iso-wall-e` boot the exported installation ISO with QEMU, exercise the public installer SSH/shell interface, and check Home Manager. John additionally checks the real GDM D-Bus interface; wall-e exercises its configured Nushell interface. |
| `module-docs` | Compares generated common-argument documentation against the committed reference. Evaluation cannot detect stale committed documentation. |

The clipboard candidate is deferred until a repository-specific integration failure
justifies it. The background clipboard probe primarily exercised upstream tooling and
fixture focus management, so it is removed. The fabricated local CUPS output queue and
the clock-format assignment assertion are also removed; discovery, access boundaries,
actual session usability, and Home Manager activation provide the retained integration value.

Underscore-prefixed examples do not enter discovery. Tests use public disposable passwords, generated test-only age
keys, isolated disks, and local service substitutes. They never use production credentials.
The networking integration orders its keyfile writer after NetworkManager and the
actual sops installation service, reloads connection profiles through `nmcli`, and propagates
reload errors. Persistence creates the machine-ID symlink target on the first boot so
systemd can initialize and preserve the identity.

## Local validation and deliberate regressions

Run policy tests without Nix or virtualization:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s .github/scripts/tests -v
```

Git policy fixtures use disposable repositories and isolate global Git configuration,
hooks, signing, and repository environment variables. Merge/API cases use mocked responses
and never merge a real PR.

Evaluate the flake and build a selected behavioral test:

```bash
nix flake check --no-build --all-systems
nix build -L .#checks.x86_64-linux.update
```

Evaluation does not execute VM tests. Desktop and ISO checks require KVM; the CI runner
makes `/dev/kvm` available to builders. Failed test scripts include service diagnostics or
serial logs. Use `--keep-failed` when investigating locally.

`regressionChecks.x86_64-linux` exports deliberate mutations separately from `checks`.
Each mutation reuses the normal assertions and must fail; it must never become a passing
required check. Build the normal case first, then confirm that the mutated case fails at
the intended assertion, rather than during dependency fetching or fixture setup.

| Regression output | Intentional change and expected failure |
| --- | --- |
| `persistence-without-user-state` | Removes preserved home directories; the user marker disappears after reboot. |
| `networkmanager-secrets-without-reload` | Replaces NetworkManager reload with a no-op; the generated WiFi profiles remain unloaded. |
| `gnome-session` | Removes the real Home Manager gesture seed activation; the configured gesture file is missing. |
| `upgrade` | Treats recorder exit 23 as success; the service failure assertion fails. |
| `printing-discovery` | Closes the desktop's Avahi firewall opening; independent mDNS discovery fails. |
| `iso-john`, `iso-wall-e` | Truncates the actual built ISO; the image cannot boot and satisfy the smoke probe. |

For example, after the normal upgrade test passes, this command must fail:

```bash
nix build -L --keep-failed .#regressionChecks.x86_64-linux.upgrade
```

Record both positive and negative execution results in the PR. An evaluation-only result
or an environmental failure is not evidence that a regression assertion executed.

The optional CI proof tier uses `.github/scripts/prove-regression.py`. A normal build must
succeed first; the mutated Nix build must exit with its normal failure status and include
the expected terminal exception in a Python traceback. Printed or traced marker text,
cancelled builds, fetch, evaluation, VM transport, and builder failures do not count as a
successful negative control. ANSI colors and ordinary Nix log prefixes are accepted.
The workflow retains both logs for 14 days. Run the complete demonstration on a KVM runner:

```bash
gh workflow run flake-build.yaml --ref <branch> -f prove-regressions=true
```

## Manual ISO builds

In GitHub Actions choose **ISO build**, select the workflow branch, choose `john`, `wall-e`,
or `both`, and optionally enter a branch, tag, or commit in `ref`. An empty `ref` uses the
selected workflow revision. Discovery resolves the ref to an immutable commit, and both
its ISO exports and matching actual-image smoke tests run at that commit.

The same operation is available through the CLI:

```bash
gh workflow run iso-build.yaml --ref main -f iso=both -f ref=main
```

Or build and boot-test an image locally:

```bash
nix build -L .#packages.x86_64-linux.host-wall-e
nix build -L .#checks.x86_64-linux.iso-wall-e
```

## Stale branch cleanup

**Clean stale branches** runs on the 9th of each month at 18:03 UTC and can also run
manually from the default branch. It deletes branches with no open PR and no commits
in the preceding calendar month. Closed and merged PRs do not prevent cleanup.
The default branch, `main`, protected branches, and open PR head or base branches
are preserved. The workflow rechecks PRs before deletion and uses a Git lease so a
concurrent push prevents deletion. Missing metadata or API errors stop deletion.
The cutoff uses commit timestamps, not the time an existing commit was pushed.
Deleted branch names appear in the workflow summary.

## Automatic dependency merging

**Merge verified dependency updates** runs after a successful PR **Flake build**. It checks
out policy code from the trusted default branch, fetches PR objects only for read-only diff
inspection, and never executes PR code with its write token. Titles, authors, labels, and
update-workflow claims alone cannot establish eligibility.

Automatic merging also requires matching base/head repository IDs and verified identities
for both the PR author and the checked workflow's original actor: the personal repository
owner's account or GitHub's `github-actions[bot]` identity. A trusted author does not make
another person's later push eligible, and an owner rerun does not override an untrusted
original workflow actor. The checked workflow and its head source must also belong to the
target repository; the global Actions bot identity from a fork cannot authorize merging.
Fork PRs, outside contributors, other collaborators, and other bots require manual review,
even when their diffs contain only lock or hash updates and every check passes. Missing
identity data blocks automation. Repository and author trust are checked again immediately
before the merge request. A PAT belonging to another service account does not implicitly
grant automatic-merge eligibility.

Eligible diffs contain only modifications to `flake.lock` and/or existing SHA256 source
hash leaves in `modules/programs-desktop/_flow-desktop/release.json`. Every existing source key, URL,
version, and other field must remain identical. Added/deleted/renamed files, file mode
changes, unsupported package formats, and mixed configuration/workflow/implementation
changes require manual merging. Add another package format only with a strict schema and
policy tests; generic text matching of Nix hash assignments is insufficient.

Lock changes must pass the complete non-ISO test suite. Hash changes require basic
validation and the packages and checks selected by their affected module directory. The merge
policy requires a successful aggregate from the completed triggering check suite at the
current PR head SHA, plus every applicable classic/ruleset required status. Missing,
pending, cancelled, failed, or skipped required checks block merging. A superseded run or
a PR retargeted while checking cannot authorize a merge.

A newer successful full run at the same revision does not hide the triggering PR's
successful aggregate. The PR's own aggregate must still exist and pass, and newer pending
or unsuccessful required results still block merging. Source metadata comparisons preserve
JSON types as well as values, so a hash update cannot also change a number into a boolean.

The final GitHub merge request specifies the validated head SHA and uses the repository's
supported merge-commit method. GitHub still enforces branch protections, strict up-to-date
requirements, and reviews. API refusals leave the PR open and are explained in the workflow
summary. This does not require enabling GitHub's separate auto-merge repository setting.

[output-ownership]: https://github.com/first-uninteresting-username/NixOS-config/blob/main/lib/modules/README.md#output-ownership
