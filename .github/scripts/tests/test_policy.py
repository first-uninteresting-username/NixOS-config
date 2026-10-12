# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later

import base64
import copy
import importlib.util
import json
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
MAPPING = json.loads((SCRIPTS / "test-map.json").read_text())
NAMES = set(MAPPING["tests"])
MATRIX = {"include": [{"name": name, "system": system, "attr": f"checks.{system}.{name}"}
                      for name in sorted(NAMES | {"iso-john", "iso-wall-e"})
                      for system in ["x86_64-linux", "aarch64-linux"]]}


class SelectionTests(unittest.TestCase):
    def selected(self, paths, mode="pr", iso="both"):
        matrix, reasons = selection.select(MATRIX, paths, MAPPING, mode, iso)
        return {row["name"] for row in matrix["include"]}, matrix, reasons

    def test_lock_shared_and_unknown_configuration_select_all(self):
        for path in ["flake.lock", "flake.nix", "hosts/common/desktop-modules.nix",
                     ".github/scripts/select-tests.py", "checks/new-test.nix",
                     ".github/nix.conf", "overlays/new.nix",
                     "modules/configuration/new-feature.nix", "hosts/armin/modules.nix"]:
            with self.subTest(path=path):
                self.assertEqual(self.selected([path])[0], NAMES)

    def test_precise_network_mapping_and_all_systems(self):
        names, matrix, reasons = self.selected(["modules/configuration/system/networking.nix"])
        self.assertEqual(names, {"networkmanager-secrets", "printing-discovery", "module-docs"})
        self.assertEqual(len(matrix["include"]), 6)
        self.assertIn("mapped to networkmanager-secrets", reasons["networkmanager-secrets"][0])

    def test_packages_and_documentation(self):
        self.assertEqual(self.selected(["packages/shell-scripts/rebuild/default.nix"])[0], {"upgrade"})
        self.assertEqual(self.selected(["packages/docs/default.nix"])[0], {"module-docs"})
        self.assertEqual(self.selected(["docs/checks.md"])[0], set())
        self.assertEqual(self.selected(["packages/new/default.nix"])[0], NAMES)

    def test_iso_only_on_demand_and_complete_weekly(self):
        self.assertEqual(self.selected(["flake.lock"])[0], NAMES)
        self.assertEqual(self.selected([], "iso", "john")[0], {"iso-john"})
        self.assertEqual(self.selected([], "iso")[0], {"iso-john", "iso-wall-e"})
        self.assertEqual(self.selected([], "weekly")[0], NAMES | {"iso-john", "iso-wall-e"})

    def test_new_check_needs_mapping(self):
        with self.assertRaises(ValueError):
            selection.select({"include": [{"name": "forgotten-check"}]}, [], MAPPING)
        with self.assertRaises(ValueError):
            selection.select({"include": []}, [], MAPPING, "weekly")

    def test_summary_records_names_systems_and_reasons(self):
        _, matrix, reasons = self.selected(["modules/configuration/services/update.nix"])
        result = selection.summary(matrix, reasons)
        self.assertIn("**upgrade**", result)
        self.assertIn("aarch64-linux", result)
        self.assertIn("modules/configuration/services/update.nix", result)
        self.assertIn("No tests selected", selection.summary({"include": []}, {}))


class GitDiffTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.git("init", "--initial-branch=main")
        self.git("config", "user.name", "CI policy test")
        self.git("config", "user.email", "ci@example.invalid")
        self.write("modules/configuration/services/update.nix", "original upgrade\n")
        self.write("modules/configuration/desktop/printing.nix", "original printing\n")
        self.write("flake.lock", '{"version": 7}\n')
        self.commit()
        self.base = self.git("rev-parse", "HEAD").strip()

    def tearDown(self):
        self.temp.cleanup()

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
        self.git("mv", "modules/configuration/services/update.nix", "upgrade-renamed.nix")
        (self.root / "modules/configuration/desktop/printing.nix").unlink()
        self.write("modules/new-configuration.nix", "added\n")
        self.commit()
        paths = selection.changed_paths(self.base, "HEAD", cwd=self.root)
        self.assertEqual(set(paths), {"modules/configuration/services/update.nix", "upgrade-renamed.nix",
                                     "modules/configuration/desktop/printing.nix", "modules/new-configuration.nix"})
        chosen, _ = selection.select(MATRIX, paths, MAPPING)
        self.assertEqual({row["name"] for row in chosen["include"]}, NAMES)

    def test_comparison_uses_merge_base_not_updated_base_tip(self):
        self.git("switch", "-c", "pr")
        self.write("docs/checks.md", "PR docs\n")
        self.commit()
        head = self.git("rev-parse", "HEAD").strip()
        self.git("switch", "main")
        self.write("modules/shared-new.nix", "new main configuration\n")
        self.commit()
        self.assertEqual(selection.changed_paths("main", head, cwd=self.root), ["docs/checks.md"])

    def test_mode_changes_cannot_be_automatic_updates(self):
        (self.root / "flake.lock").chmod(0o755)
        self.write("flake.lock", '{"version": 8}\n')
        self.commit()
        with patch.object(merge, "git", side_effect=lambda *args: subprocess.run(
                ["git", *args], cwd=self.root, check=True, capture_output=True).stdout):
            changes = merge.revision_changes(self.base, "HEAD")
        self.assertEqual(changes[0][0], "mode")
        self.assertFalse(merge.eligible(changes)[0])


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


class RegressionProofTests(unittest.TestCase):
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
                                         regression.BuildResult(1, f"test-run> {exception}: "
                                                                f"CHECKS_V2_REGRESSION:{marker}: "
                                                                "command output\n")])
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

    def test_unrelated_failures_and_logged_source_do_not_count(self):
        for output in ["error: hash mismatch in fixed-output derivation", "error: evaluation failed",
                       "QEMU exited with status 1", "No space left on device", "cannot access /dev/kvm",
                       'assert status != 0, "CHECKS_V2_REGRESSION:upgrade-failure-propagation"',
                       "CHECKS_V2_REGRESSION:upgrade-failure-propagation",
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
                     "packages/new/default.nix", "packages/flow-desktop/default.nix"]:
            self.assertFalse(merge.eligible([self.change(), self.change(path=path)])[0])

    def test_noop_duplicate_json_and_invalid_lock_block(self):
        self.assertFalse(merge.source_hash_only(json.dumps(self.old), json.dumps(self.old)))
        self.assertFalse(merge.source_hash_only('{"sources":{},"sources":{}}', json.dumps(self.new)))
        self.assertFalse(merge.eligible([("M", "flake.lock", b"{}", b"not JSON")])[0])


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


class MergeRaceTests(unittest.TestCase):
    SHA = "a" * 40

    def pr(self, sha=None):
        return {"number": 42, "state": "open", "draft": False,
                "base": {"ref": "main", "sha": "c" * 40}, "head": {"sha": sha or self.SHA}}

    def api(self, changed=False, retargeted=False, base_advanced=False):
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

    def exercise(self, changed=False, fetched=None, retargeted=False, base_advanced=False):
        api = self.api(changed, retargeted, base_advanced)
        revisions = iter([("c" * 40 + "\n").encode(), ((fetched or self.SHA) + "\n").encode()])
        with patch.object(merge, "git", side_effect=lambda *args: next(revisions)
                          if args[0] == "rev-parse" else b""), \
                patch.object(merge, "revision_changes", return_value=[("M", "flake.lock", b"{}", b'{"version":7}')]):
            result = merge.process(api, {"head_sha": self.SHA, "check_suite_id": 123}, self.pr(), "main")
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
            result = merge.process(api, {"head_sha": "b" * 40}, self.pr(), "main")
        mocked.assert_not_called()
        self.assertEqual(api.merges, [])
        self.assertIn("superseded", result)


if __name__ == "__main__":
    unittest.main()
