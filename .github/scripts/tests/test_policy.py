# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later

import base64
import copy
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


SCRIPTS = Path(__file__).resolve().parents[1]


def load(name):
    spec = importlib.util.spec_from_file_location(name, SCRIPTS / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


selection = load("select-tests")
aggregate = load("aggregate-status")
merge = load("auto-merge")
regression = load("prove-regression")
class GitDiffTests(unittest.TestCase):
    def setUp(self):
        environment = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
        environment.update({"GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": os.devnull,
                            "GIT_TERMINAL_PROMPT": "0"})
        isolation = patch.dict(os.environ, environment, clear=True)
        isolation.start()
        self.addCleanup(isolation.stop)
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.git("init", "--initial-branch=main")
        self.git("config", "user.name", "CI policy test")
        self.git("config", "user.email", "ci@example.invalid")
        self.write("modules/update/default.nix", "original upgrade\n")
        self.write("modules/printing/default.nix", "original printing\n")
        self.write("flake.lock", '{"version": 7}\n')
        self.commit()
        self.base = self.git("rev-parse", "HEAD").strip()

    def git(self, *args):
        return subprocess.run(["git", *args], cwd=self.root, check=True,
                              text=True, capture_output=True).stdout

    def write(self, path, text):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text)

    def commit(self):
        self.git("add", "-A")
        self.git("commit", "-m", "test revision")

    def test_added_deleted_and_renamed_paths_are_selected(self):
        self.git("mv", "modules/update/default.nix", "upgrade-renamed.nix")
        (self.root / "modules/printing/default.nix").unlink()
        self.write("modules/new-configuration.nix", "added\n")
        self.commit()
        paths = selection.changed_paths(self.base, "HEAD", cwd=self.root)
        self.assertEqual(set(paths), {"modules/update/default.nix", "upgrade-renamed.nix",
                                     "modules/printing/default.nix", "modules/new-configuration.nix"})

    def test_comparison_uses_merge_base_not_updated_base_tip(self):
        self.git("switch", "-c", "pr")
        self.write("docs/checks.md", "PR docs\n")
        self.commit()
        head = self.git("rev-parse", "HEAD").strip()
        self.git("switch", "main")
        self.write("modules/shared-new.nix", "new main configuration\n")
        self.commit()
        self.assertEqual(selection.changed_paths("main", head, cwd=self.root), ["docs/checks.md"])

    def test_nul_delimited_diff_preserves_unusual_filenames(self):
        paths = ["modules/example/line\nbreak", "modules/example/space name", "docs/[literal].md"]
        for path in paths:
            self.write(path, "fixture\n")
        self.commit()
        self.assertEqual(set(selection.changed_paths(self.base, "HEAD", cwd=self.root)), set(paths))

    def test_mode_changes_cannot_be_automatic_updates(self):
        (self.root / "flake.lock").chmod(0o755)
        self.write("flake.lock", '{"version": 8}\n')
        self.commit()
        with patch.object(merge, "git", side_effect=lambda *args: subprocess.run(
                ["git", *args], cwd=self.root, check=True, capture_output=True).stdout):
            changes = merge.revision_changes(self.base, "HEAD")
        self.assertEqual(changes[0][0], "mode")
        self.assertFalse(merge.eligible(changes)[0])


class GitEnvironmentTests(unittest.TestCase):
    def test_git_fixtures_ignore_user_hooks_signing_and_repository_environment(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            hooks = root / "hooks"
            hooks.mkdir()
            hook = hooks / "pre-commit"
            hook.write_text("#!/bin/sh\nexit 73\n")
            hook.chmod(0o755)
            config = root / "gitconfig"
            config.write_text(f"[core]\n hooksPath = {hooks}\n fileMode = false\n"
                              "[commit]\n gpgSign = true\n")
            environment = {**os.environ, "GIT_CONFIG_GLOBAL": str(config),
                           "GIT_DIR": str(root / "foreign-repository"),
                           "GIT_WORK_TREE": str(root),
                           "GIT_INDEX_FILE": str(root / "foreign-index"),
                           "GIT_CONFIG_COUNT": "1", "GIT_CONFIG_KEY_0": "commit.gpgsign",
                           "GIT_CONFIG_VALUE_0": "true"}
            result = subprocess.run(
                [sys.executable, str(Path(__file__).resolve()),
                 "GitDiffTests.test_added_deleted_and_renamed_paths_are_selected",
                 "GitDiffTests.test_mode_changes_cannot_be_automatic_updates"],
                env=environment, capture_output=True, text=True, timeout=30,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertFalse((root / "foreign-index").exists())
            self.assertFalse((root / "foreign-repository").exists())


class AggregateTests(unittest.TestCase):
    def jobs(self, selected=False, weekly=False, prove=False):
        return {"basic": "success", "discover": "success", "packages": "success",
                "tests": "success" if selected else "skipped",
                "hosts": "success" if weekly else "skipped",
                "isos": "success" if weekly else "skipped",
                "regressions": "success" if prove else "skipped"}

    def test_intentional_omissions_and_complete_runs_pass(self):
        self.assertEqual(aggregate.failures(self.jobs(), False, False), [])
        self.assertEqual(aggregate.failures(self.jobs(True, True), True, True), [])
        self.assertEqual(aggregate.failures(self.jobs(True, True, True), True, True, True), [])

    def test_every_unsuccessful_required_tier_blocks(self):
        for name in self.jobs(True, True, True):
            for result in ["failure", "cancelled", "skipped", "pending", None]:
                with self.subTest(name=name, result=result):
                    jobs = self.jobs(True, True, True)
                    jobs[name] = result
                    self.assertTrue(aggregate.failures(jobs, True, True, True))

    def test_missing_or_unexpectedly_executed_job_blocks(self):
        jobs = self.jobs()
        del jobs["discover"]
        self.assertTrue(aggregate.failures(jobs, False, False))
        self.assertTrue(aggregate.failures(self.jobs(False, True), False, True))
        jobs = self.jobs()
        jobs["tests"] = "success"
        self.assertTrue(aggregate.failures(jobs, False, False))

    def test_requested_regression_proof_cannot_be_omitted(self):
        self.assertTrue(aggregate.failures(self.jobs(True, True), True, True, True))
        self.assertTrue(aggregate.failures(self.jobs(True, True, True), True, True, False))


    def test_empty_package_selection_is_explicit_and_enforced(self):
        jobs = self.jobs()
        jobs["packages"] = "skipped"
        self.assertEqual(aggregate.failures(jobs, False, False, selected_packages=False), [])
        for result in ["success", "failure", "cancelled", "pending", None]:
            with self.subTest(result=result):
                jobs["packages"] = result
                self.assertTrue(aggregate.failures(jobs, False, False, selected_packages=False))
        jobs["packages"] = "skipped"
        self.assertTrue(aggregate.failures(jobs, False, False, selected_packages=True))
        self.assertTrue(aggregate.failures(jobs, True, True, selected_packages=False))

class RegressionProofTests(unittest.TestCase):
    def failure(self, exception, marker, prefix="test-run> "):
        return (f"{prefix}Traceback (most recent call last):\n"
                f'{prefix}  File "/nix/store/test-driver/driver.py", line 41, in run_tests\n'
                f"{prefix}    run_test()\n"
                f"{prefix}{exception}: CHECKS_V2_REGRESSION:{marker}: command output\n")

    def runner(self, results):
        calls = []

        def run(command):
            calls.append(command)
            return results.pop(0)

        return run, calls

    def test_all_seven_cases_require_baseline_and_specific_negative_failure(self):
        self.assertEqual(len(regression.CASES), 7)
        for case, (normal, exception, marker) in regression.CASES.items():
            with self.subTest(case=case):
                run, calls = self.runner([regression.BuildResult(0, "normal succeeds\n"),
                                         regression.BuildResult(1, self.failure(exception, marker))])
                outcome = regression.prove(case, runner=run)
                self.assertIn("deliberate regression failed", outcome)
                self.assertEqual(calls, [
                    ["nix", "build", f".#checks.x86_64-linux.{normal}", "--no-link", "-L"],
                    ["nix", "build", f".#regressionChecks.x86_64-linux.{case}", "--no-link", "-L"]])

    def test_baseline_failure_never_attempts_negative_build(self):
        run, calls = self.runner([regression.BuildResult(1, "cannot access /dev/kvm")])
        with self.assertRaisesRegex(regression.ProofError, "baseline"):
            regression.prove("upgrade", runner=run)
        self.assertEqual(len(calls), 1)

    def test_unexpected_negative_success_is_rejected(self):
        run, _ = self.runner([regression.BuildResult(0, ""), regression.BuildResult(0, "")])
        with self.assertRaisesRegex(regression.ProofError, "unexpectedly passed"):
            regression.prove("upgrade", runner=run)

    def test_negative_cancellation_cannot_count_as_proof(self):
        output = self.failure("AssertionError", "upgrade-failure-propagation")
        for status in [-15, -9, 130, 137, 143, 2]:
            with self.subTest(status=status):
                run, _ = self.runner([regression.BuildResult(0, ""), regression.BuildResult(status, output)])
                with self.assertRaisesRegex(regression.ProofError, "exit status"):
                    regression.prove("upgrade", runner=run)

    def test_plain_prefixed_summary_and_colored_tracebacks_are_accepted(self):
        for prefix in ["", "vm-test-run-upgrade> ", "       > "]:
            for colored in [False, True]:
                with self.subTest(prefix=prefix, colored=colored):
                    output = self.failure("AssertionError", "upgrade-failure-propagation", prefix)
                    # An annotated Python source line is not the terminal exception.
                    output = output.replace("run_test()", "command: str = run_test()")
                    if colored:
                        output = "\x1b[35m" + output + "\x1b[0m"
                    run, _ = self.runner([regression.BuildResult(0, ""), regression.BuildResult(1, output)])
                    self.assertIn("deliberate regression failed", regression.prove("upgrade", runner=run))

    def test_unrelated_failures_and_logged_source_do_not_count(self):
        for output in ["error: hash mismatch in fixed-output derivation", "error: evaluation failed",
                       "QEMU exited with status 1", "No space left on device", "cannot access /dev/kvm",
                       'assert status != 0, "CHECKS_V2_REGRESSION:upgrade-failure-propagation"',
                       "CHECKS_V2_REGRESSION:upgrade-failure-propagation",
                       "AssertionError: CHECKS_V2_REGRESSION:upgrade-failure-propagation",
                       "trace: AssertionError: CHECKS_V2_REGRESSION:upgrade-failure-propagation",
                       self.failure("AssertionError", "upgrade-failure-propagation", "trace: "),
                       self.failure("AssertionError", "persistence-user-state")
                       + "test-run> AssertionError: CHECKS_V2_REGRESSION:upgrade-failure-propagation",
                       self.failure("AssertionError", "upgrade-failure-propagation-extra"),
                       "AssertionError: CHECKS_V2_REGRESSION:persistence-user-state",
                       "AssertionError: CHECKS_V2_REGRESSION:upgrade-failure-propagation-extra"]:
            with self.subTest(output=output):
                run, _ = self.runner([regression.BuildResult(0, ""), regression.BuildResult(1, output)])
                with self.assertRaisesRegex(regression.ProofError, "expected assertion"):
                    regression.prove("upgrade", runner=run)


def sri(byte):
    return "sha256-" + base64.b64encode(bytes([byte]) * 32).decode()


class EligibilityTests(unittest.TestCase):
    def setUp(self):
        self.old = {"version": "1.0", "sources": {
            "x86_64-linux": {"url": "https://example.invalid/x86.deb", "hash": sri(1)},
            "aarch64-linux": {"url": "https://example.invalid/arm.deb", "hash": sri(2)}}}
        self.new = copy.deepcopy(self.old)
        self.new["sources"]["x86_64-linux"]["hash"] = sri(3)

    def change(self, path=merge.HASH_FILE, status="M", before=None, after=None):
        return (status, path, json.dumps(self.old if before is None else before).encode(),
                json.dumps(self.new if after is None else after).encode())

    def test_lock_hash_and_combination_eligible(self):
        lock = self.change("flake.lock", before={"version": 7}, after={"version": 7, "nodes": {}})
        for changes in [[lock], [self.change()], [lock, self.change()]]:
            self.assertTrue(merge.eligible(changes)[0])

    def test_versions_urls_structure_and_invalid_hashes_block(self):
        variants = []
        for key, value in [("version", "2.0"), ("unexpected", True)]:
            changed = copy.deepcopy(self.new)
            changed[key] = value
            variants.append(changed)
        for key, value in [("url", "https://elsewhere.invalid/source"), ("hash", "sha256-AAAA"),
                           ("hash", 42), ("hash", ""), ("hash", "sha256-" + "!" * 44)]:
            changed = copy.deepcopy(self.new)
            changed["sources"]["x86_64-linux"][key] = value
            variants.append(changed)
        changed = copy.deepcopy(self.new)
        del changed["sources"]["aarch64-linux"]
        variants.append(changed)
        for changed in variants:
            with self.subTest(changed=changed):
                self.assertFalse(merge.eligible([self.change(after=changed)])[0])

    def test_added_deleted_renamed_mixed_and_empty_block(self):
        self.assertFalse(merge.eligible([])[0])
        for status in ["A", "D", "R100", "mode"]:
            self.assertFalse(merge.eligible([self.change(status=status)])[0])
        for path in ["flake.nix", "modules/change.nix", ".github/workflows/flake-build.yaml",
                     "packages/new/default.nix", "modules/programs-desktop/_flow-desktop/package.nix"]:
            self.assertFalse(merge.eligible([self.change(), self.change(path=path)])[0])

    def test_noop_duplicate_json_and_invalid_lock_block(self):
        self.assertFalse(merge.source_hash_only(json.dumps(self.old), json.dumps(self.old)))
        self.assertFalse(merge.source_hash_only('{"sources":{},"sources":{}}', json.dumps(self.new)))
        self.assertFalse(merge.eligible([("M", "flake.lock", b"{}", b"not JSON")])[0])

    def test_source_metadata_types_cannot_change_with_hashes(self):
        before = {**self.old, "releaseNumber": 1}
        for value in [True, 1.0]:
            with self.subTest(value=value):
                after = {**self.new, "releaseNumber": value}
                self.assertFalse(merge.eligible([self.change(before=before, after=after)])[0])


class CurrentStatusTests(unittest.TestCase):
    SHA = "a" * 40
    REQUIRED = {(merge.AGGREGATE, merge.ACTIONS_APP)}

    def check(self, ident=10, **changes):
        result = {"name": merge.AGGREGATE, "head_sha": self.SHA, "id": ident,
                  "app": {"id": merge.ACTIONS_APP}, "status": "completed", "conclusion": "success",
                  "check_suite": {"id": 123}}
        result.update(changes)
        return result

    def problems(self, checks, statuses=None, required=None):
        return merge.check_failures(self.SHA, checks, statuses or [], required or self.REQUIRED, 123)

    def test_current_success_passes_and_old_sha_or_other_app_cannot(self):
        self.assertEqual(self.problems([self.check()]), [])
        self.assertTrue(self.problems([self.check(head_sha="b" * 40)]))
        self.assertTrue(self.problems([self.check(app={"id": 9})]))
        self.assertTrue(self.problems([self.check(check_suite={"id": 999})]))

    def test_failure_cancellation_pending_skips_and_latest_rerun(self):
        for conclusion in ["failure", "cancelled", "skipped", "neutral", "timed_out", None]:
            self.assertTrue(self.problems([self.check(conclusion=conclusion)]))
        self.assertTrue(self.problems([self.check(status="queued", conclusion=None)]))
        self.assertTrue(self.problems([self.check(), self.check(11, status="in_progress", conclusion=None)]))
        self.assertEqual(self.problems([self.check(conclusion="failure"), self.check(11)]), [])

    def test_extra_classic_and_ruleset_checks_are_required(self):
        branch = {"protection": {"required_status_checks": {
            "contexts": ["lint", "classic"], "checks": [{"context": "classic", "app_id": 77}]}}}
        rules = [{"type": "required_status_checks", "parameters": {
            "required_status_checks": [{"context": "security", "integration_id": 88}]}}]
        required = merge.required_contexts(branch, rules)
        self.assertEqual(required, self.REQUIRED | {("lint", None), ("classic", 77), ("security", 88)})
        self.assertTrue(self.problems([self.check()], required=required))

    def test_latest_legacy_status_cannot_hide_pending(self):
        required = self.REQUIRED | {("lint", None)}
        success = {"context": "lint", "id": 2, "state": "success"}
        pending = {"context": "lint", "id": 3, "state": "pending"}
        self.assertEqual(self.problems([self.check()], [success], required), [])
        self.assertTrue(self.problems([self.check()], [success, pending], required))

    def test_newer_full_run_success_does_not_replace_or_invalidate_pr_success(self):
        full = self.check(11, check_suite={"id": 999})
        self.assertEqual(self.problems([self.check(), full]), [])
        self.assertTrue(self.problems([self.check(conclusion="failure"), full]))
        for changes in [{"status": "in_progress", "conclusion": None}, {"conclusion": "failure"}]:
            with self.subTest(changes=changes):
                self.assertTrue(self.problems([self.check(), {**full, **changes}]))


class UpdateTrustTests(unittest.TestCase):
    REPOSITORY = {"id": 101, "owner": {"id": 7, "login": "owner", "type": "User"}}
    BOT = {"id": merge.ACTION_BOT_ID, "login": "github-actions[bot]", "type": "Bot"}

    def pr(self, author=None, head_id=101):
        return {"base": {"repo": {"id": 101}}, "head": {"repo": {"id": head_id}},
                "user": copy.deepcopy(author if author is not None else self.REPOSITORY["owner"])}

    def test_owner_and_verified_actions_bot_are_trusted_in_same_repository(self):
        for author in [self.REPOSITORY["owner"], self.BOT]:
            with self.subTest(author=author):
                self.assertTrue(merge.allowed_update(self.pr(author), self.REPOSITORY)[0])

    def test_forks_are_rejected_even_for_owner_and_verified_bot(self):
        for author in [self.REPOSITORY["owner"], self.BOT]:
            for head_id in [202, None]:
                with self.subTest(author=author, head_id=head_id):
                    self.assertFalse(merge.allowed_update(self.pr(author, head_id), self.REPOSITORY)[0])

    def test_unknown_authors_and_username_impersonation_are_rejected(self):
        for author in [{"id": 99, "login": "stranger", "type": "User"},
                       {"id": 99, "login": "owner", "type": "User"},
                       {"id": 99, "login": "github-actions[bot]", "type": "Bot"},
                       {**self.BOT, "id": float(merge.ACTION_BOT_ID)},
                       {**self.BOT, "type": "User"}, {**self.BOT, "login": "other-bot"}]:
            with self.subTest(author=author):
                self.assertFalse(merge.allowed_update(self.pr(author), self.REPOSITORY)[0])

    def test_missing_or_invalid_identity_requires_manual_review(self):
        for side in ["base", "head"]:
            for repository in [None, {}, {"id": True}, {"id": 202}]:
                pr = self.pr()
                pr[side]["repo"] = repository
                with self.subTest(side=side, repository=repository):
                    self.assertFalse(merge.allowed_update(pr, self.REPOSITORY)[0])
        for repository in [{}, {"id": None}, {"id": True}, {"id": 0}]:
            self.assertFalse(merge.allowed_update(self.pr(), repository)[0])
        for author in [{}, {"id": None, "type": "User"}, {"id": True, "type": "User"}]:
            self.assertFalse(merge.allowed_update(self.pr(author), self.REPOSITORY)[0])

    def test_organization_members_are_not_implicitly_trusted(self):
        repository = {"id": 101, "owner": {"id": 7, "login": "organization", "type": "Organization"}}
        self.assertFalse(merge.allowed_update(self.pr(), repository)[0])
        self.assertTrue(merge.allowed_update(self.pr(self.BOT), repository)[0])


class MergeRaceTests(unittest.TestCase):
    """Simulate PR changes between API reads to reject stale authorization or checks."""
    SHA = "a" * 40
    REPOSITORY = UpdateTrustTests.REPOSITORY

    def workflow_run(self, sha=None, actor=None):
        return {"head_sha": sha or self.SHA, "check_suite_id": 123,
                "repository": {"id": 101}, "head_repository": {"id": 101},
                "actor": copy.deepcopy(actor if actor is not None else self.REPOSITORY["owner"])}

    def pr(self, sha=None):
        return {"number": 42, "state": "open", "draft": False,
                "base": {"ref": "main", "sha": "c" * 40, "repo": {"id": 101}},
                "head": {"sha": sha or self.SHA, "repo": {"id": 101}},
                "user": copy.deepcopy(self.REPOSITORY["owner"])}

    def api(self, changed=False, retargeted=False, base_advanced=False, untrusted=False, forked=False):
        class FakeAPI:
            merges = []

            def request(inner, path, method="GET", body=None):
                if path == "/branches/main":
                    return {}
                if path == "/rules/branches/main":
                    return []
                if path == "/pulls/42":
                    result = self.pr("b" * 40 if changed else None)
                    if retargeted:
                        result["base"]["ref"] = "other-branch"
                    if base_advanced:
                        result["base"]["sha"] = "d" * 40
                    if untrusted:
                        result["user"]["id"] = 99
                    if forked:
                        result["head"]["repo"]["id"] = 202
                    return result
                if path == "/pulls/42/merge":
                    inner.merges.append(body)
                    return {"message": "merged"}
                raise AssertionError(path)

            def pages(inner, path, key=None):
                if "check-runs" in path:
                    return [{"name": merge.AGGREGATE, "head_sha": self.SHA, "id": 10,
                             "app": {"id": merge.ACTIONS_APP}, "status": "completed",
                             "conclusion": "success", "check_suite": {"id": 123}}]
                return []

        return FakeAPI()

    def exercise(self, changed=False, fetched=None, retargeted=False, base_advanced=False,
                 untrusted=False, forked=False, actor=None):
        api = self.api(changed, retargeted, base_advanced, untrusted, forked)
        revisions = iter([("c" * 40 + "\n").encode(), ((fetched or self.SHA) + "\n").encode()])
        with patch.object(merge, "git", side_effect=lambda *args: next(revisions)
                          if args[0] == "rev-parse" else b""), \
                patch.object(merge, "revision_changes", return_value=[("M", "flake.lock", b"{}", b'{"version":7}')]):
            result = merge.process(api, self.workflow_run(actor=actor), self.pr(),
                                   "main", self.REPOSITORY)
        return api.merges, result

    def test_merge_sends_exact_sha_and_supported_merge_method(self):
        writes, result = self.exercise()
        self.assertEqual(writes, [{"sha": self.SHA, "merge_method": "merge"}])
        self.assertIn("merged", result)

    def test_changed_head_after_checks_never_merges(self):
        writes, result = self.exercise(changed=True)
        self.assertEqual(writes, [])
        self.assertIn("PR changed", result)

    def test_changed_head_during_fetch_never_merges(self):
        writes, result = self.exercise(fetched="b" * 40)
        self.assertEqual(writes, [])
        self.assertIn("head changed", result)

    def test_retargeted_pr_or_advanced_base_never_merges(self):
        for options in [{"retargeted": True}, {"base_advanced": True}]:
            writes, result = self.exercise(**options)
            self.assertEqual(writes, [])
            self.assertIn("PR changed", result)

    def test_superseded_workflow_run_never_fetches_or_merges(self):
        api = self.api()
        with patch.object(merge, "git") as mocked:
            result = merge.process(api, self.workflow_run("b" * 40), self.pr(), "main", self.REPOSITORY)
        mocked.assert_not_called()
        self.assertEqual(api.merges, [])
        self.assertIn("superseded", result)

    def test_outsider_or_fork_never_reaches_fetch_checks_or_merge(self):
        for outsider, forked in [(True, False), (False, True), (True, True)]:
            pr = self.pr()
            if outsider:
                pr["user"]["id"] = 99
            if forked:
                pr["head"]["repo"]["id"] = 202
            api = self.api()
            with patch.object(merge, "git") as mocked_git, patch.object(api, "request") as requests:
                result = merge.process(api, self.workflow_run(), pr,
                                       "main", self.REPOSITORY)
            mocked_git.assert_not_called()
            requests.assert_not_called()
            self.assertEqual(api.merges, [])
            self.assertIn("manual merge", result)

    def test_author_and_repository_trust_are_rechecked_before_merge(self):
        for options in [{"untrusted": True}, {"forked": True}]:
            with self.subTest(options=options):
                writes, result = self.exercise(**options)
                self.assertEqual(writes, [])
                self.assertIn("trust changed", result)

    def test_unknown_commit_actor_cannot_reuse_a_trusted_pr_author(self):
        for author in [self.REPOSITORY["owner"], UpdateTrustTests.BOT]:
            for actor in [None, {"id": 99, "login": "owner", "type": "User"},
                          {"id": 99, "login": "github-actions[bot]", "type": "Bot"}]:
                pr = self.pr()
                pr["user"] = copy.deepcopy(author)
                run = self.workflow_run()
                run["actor"] = actor
                # A later owner rerun must not launder an outsider's original workflow actor.
                run["triggering_actor"] = copy.deepcopy(self.REPOSITORY["owner"])
                api = self.api()
                with patch.object(merge, "git") as mocked_git, patch.object(api, "request") as requests:
                    result = merge.process(api, run, pr, "main", self.REPOSITORY)
                mocked_git.assert_not_called()
                requests.assert_not_called()
                self.assertEqual(api.merges, [])
                self.assertIn("workflow identity", result)

    def test_foreign_workflow_cannot_authorize_same_repository_pr(self):
        for field in ["repository", "head_repository"]:
            for source in [None, {"id": 202}, {"id": True}]:
                run = self.workflow_run(actor=UpdateTrustTests.BOT)
                run[field] = source
                api = self.api()
                with patch.object(merge, "git") as mocked_git, patch.object(api, "request") as requests:
                    result = merge.process(api, run, self.pr(), "main", self.REPOSITORY)
                mocked_git.assert_not_called()
                requests.assert_not_called()
                self.assertEqual(api.merges, [])
                self.assertIn("workflow identity", result)

    def test_owner_and_verified_bot_workflow_actors_can_merge_allowed_updates(self):
        for actor in [self.REPOSITORY["owner"], UpdateTrustTests.BOT]:
            with self.subTest(actor=actor):
                writes, _ = self.exercise(actor=actor)
                self.assertEqual(writes, [{"sha": self.SHA, "merge_method": "merge"}])


if __name__ == "__main__":
    unittest.main()
