# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later

import copy
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch


SCRIPTS = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("selection", SCRIPTS / "select-tests.py")
selection = importlib.util.module_from_spec(spec)
spec.loader.exec_module(selection)
SYSTEMS = ["x86_64-linux", "aarch64-linux"]


def add_target(snapshot, kind, name, module, system="x86_64-linux", directory=None):
    directory = directory or f"modules/{module}"
    snapshot["ownership"][system][kind][name] = {
        "module": module, "source": f"{directory}/default.nix", "directory": directory,
    }
    key = (kind, system, name)
    tier = ("isoTests" if kind == "checks" else "isos") if selection.is_iso(key) else (
        "tests" if kind == "checks" else "packages")
    snapshot[tier]["include"].append({"name": name, "system": system, "type": kind,
                                      "attr": f'{kind}.{system}."{name}"'})


def snapshot():
    result = {"ownership": {system: {"system": system, "schemaVersion": 2,
                                     "packages": {}, "checks": {}} for system in SYSTEMS},
              **{tier: {"include": []} for tier in selection.KINDS}}
    for system in SYSTEMS:
        add_target(result, "packages", "example-tool", "example", system)
        add_target(result, "checks", "docs", "docs", system)
    add_target(result, "checks", "example", "example")
    add_target(result, "checks", "neighbor", "neighbor")
    for host in ["john", "wall-e"]:
        add_target(result, "packages", f"host-{host}", f"host-{host}")
        add_target(result, "checks", f"iso-{host}", "iso")
    return result


class SelectionTests(unittest.TestCase):
    """Compare independent base/head snapshots, including moved and deleted exports."""
    def setUp(self):
        self.head = snapshot()
        self.base = copy.deepcopy(self.head)

    def select(self, paths, head=None, base=None, mode="pr"):
        return selection.select(head or self.head, paths, self.base if base is None else base, mode)

    def names(self, paths, tier="tests", **kwargs):
        return {row["name"] for row in self.select(paths, **kwargs)[0][tier]["include"]}

    def test_directory_changes_select_all_owned_checks_and_packages_on_available_systems(self):
        for path in ["modules/example/default.nix", "modules/example/_checks/new.py",
                     "modules/example/README.md", "modules/example/_source/deep/helper.sh"]:
            with self.subTest(path=path):
                matrices, reasons, _ = self.select([path])
                self.assertEqual({row["name"] for row in matrices["tests"]["include"]}, {"example"})
                self.assertEqual({row["system"] for row in matrices["tests"]["include"]}, {SYSTEMS[0]})
                self.assertEqual({row["system"] for row in matrices["packages"]["include"]}, set(SYSTEMS))
                self.assertIn(path, next(iter(reasons[("checks", SYSTEMS[0], "example")])))

    def test_other_modules_do_not_select_unrelated_checks(self):
        self.assertEqual(self.names(["modules/neighbor/default.nix"]), {"neighbor"})
        self.assertEqual(self.names(["modules/neighbor/default.nix"], "packages"), set())
        self.assertEqual(self.names(["modules/example-similar/default.nix"]), set())
        self.assertEqual(self.names(["docs/reference.md"]), set())

    def test_legacy_watches_never_select_another_module(self):
        for system in SYSTEMS:
            self.base["ownership"][system]["schemaVersion"] = 1
            for kind in ["packages", "checks"]:
                for owner in self.base["ownership"][system][kind].values():
                    owner["extraFiles"] = []
        self.base["ownership"][SYSTEMS[0]]["checks"]["example"]["extraFiles"] = [
            "modules/neighbor/default.nix", "docs/reference.md"]
        self.assertEqual(self.names(["modules/neighbor/default.nix"]), {"neighbor"})
        self.assertEqual(self.names(["docs/reference.md"]), set())
        self.assertEqual(self.names(["modules/example/deleted-helper"]), {"example"})

    def test_modules_without_checks_do_not_add_tests(self):
        add_target(self.head, "packages", "new-tool", "new")
        self.assertEqual(self.names(["modules/new/_source/file"]), set())
        self.assertEqual(self.names(["modules/new/_source/file"], "packages"), {"new-tool"})
        self.assertEqual(self.names(["modules/no-outputs/default.nix"]), set())
        self.assertEqual(self.names(["modules/no-outputs/default.nix"], "packages"), set())

    def test_shared_changes_select_full_non_iso_suite(self):
        for path in ["flake.lock", "flake.nix", "arguments/user.nix", "lib/helper.nix",
                     "github-actions/default.nix", "checks/new.nix",
                     ".github/scripts/select-tests.py", ".github/scripts/aggregate-status.py",
                     ".github/scripts/prove-regression.py", ".github/workflows/flake-build.yaml",
                     ".github/workflows/flake-check.yaml", ".github/workflows/build-targets.yaml",
                     ".github/workflows/regression-checks.yaml", ".github/workflows/iso-build.yaml",
                     ".github/nix.conf",
                     "modules/user/default.nix", "modules/home-manager/default.nix"]:
            with self.subTest(path=path):
                matrices, _, _ = self.select([path])
                self.assertEqual(matrices["tests"], self.head["tests"])
                self.assertEqual(matrices["packages"], self.head["packages"])

    def test_empty_and_documentation_only_selections(self):
        for paths in [[], ["docs/checks.md"], ["README.md"], ["hosts/example.nix"],
                      ["devenv.nix"], ["devenv.yaml"], ["overlays/new.nix"],
                      [".github/workflows/docs.yaml"], [".github/workflows/cleanup-branches.yaml"],
                      [".github/scripts/auto-merge.py"], [".github/scripts/tests/test_policy.py"]]:
            with self.subTest(paths=paths):
                matrices, reasons, retired = self.select(paths)
                self.assertEqual(matrices, {"packages": {"include": []}, "tests": {"include": []}})
                self.assertEqual(reasons, {})
                self.assertEqual(retired, set())

    def test_new_checks_require_only_generated_ownership(self):
        add_target(self.head, "checks", "new-test", "new")
        self.assertEqual(self.names(["modules/new/default.nix"]), {"new-test"})

    def test_moved_declaration_uses_base_directory_and_follows_module(self):
        for system in SYSTEMS:
            for kind in ["checks", "packages"]:
                for owner in self.head["ownership"][system][kind].values():
                    if owner["module"] == "example":
                        owner.update(directory="modules/moved", source="modules/moved/default.nix")
        self.assertEqual(self.names(["modules/example/deleted-helper"]), {"example"})
        self.assertEqual(self.names(["modules/example/deleted-helper"], "packages"), {"example-tool"})

    def test_renamed_outputs_follow_module_and_removed_targets_are_reported(self):
        owner = self.head["ownership"][SYSTEMS[0]]["checks"].pop("example")
        self.head["tests"]["include"] = [row for row in self.head["tests"]["include"]
                                          if row["name"] != "example"]
        add_target(self.head, "checks", "renamed", "example", directory="modules/moved")
        matrices, _, retired = self.select([f"{owner['directory']}/deleted"])
        self.assertEqual({row["name"] for row in matrices["tests"]["include"]}, {"renamed"})
        self.assertIn(("checks", SYSTEMS[0], "example"), retired)

    def test_deleted_module_has_no_nonexistent_build_targets(self):
        self.head["ownership"][SYSTEMS[0]]["checks"].pop("neighbor")
        self.head["tests"]["include"] = [row for row in self.head["tests"]["include"]
                                          if row["name"] != "neighbor"]
        matrices, _, retired = self.select(["modules/neighbor/default.nix"])
        self.assertEqual(matrices["tests"]["include"], [])
        self.assertIn(("checks", SYSTEMS[0], "neighbor"), retired)

    def test_multiple_declarations_in_one_directory(self):
        add_target(self.head, "checks", "sibling", "sibling", directory="modules/example")
        self.assertEqual(self.names(["modules/example/README.md"]), {"example", "sibling"})

    def test_base_target_follows_changed_ownership_at_head(self):
        owner = self.head["ownership"][SYSTEMS[0]]["checks"]["example"]
        owner.update(module="different", source="modules/different/default.nix",
                     directory="modules/different")
        self.assertEqual(self.names(["modules/example/deleted-fixture"]), {"example"})

    def test_bootstrap_and_full_runs_keep_all_ordinary_outputs(self):
        for mode in ["pr", "weekly"]:
            matrices, reasons, _ = selection.select(self.head, [], None, mode)
            self.assertEqual(matrices["tests"], self.head["tests"])
            self.assertEqual(matrices["packages"], self.head["packages"])
            self.assertTrue(reasons)

    def test_iso_tier_is_separate_even_for_module_or_lock_changes(self):
        self.assertEqual(self.names(["modules/iso/default.nix"]), set())
        self.assertEqual(self.names(["modules/host-john/default.nix"], "packages"), set())
        self.assertFalse(any(name.startswith("iso-") for name in self.names(["flake.lock"])))
        chosen = selection.select_iso(self.head["isoTests"], "john")
        self.assertEqual({row["name"] for row in chosen["include"]}, {"iso-john"})
        self.assertEqual(selection.select_iso(self.head["isoTests"], "both"), self.head["isoTests"])
        with self.assertRaisesRegex(ValueError, "missing"):
            selection.select_iso({"include": []}, "both")

    def test_metadata_and_matrices_must_match_in_both_revisions(self):
        for revision in [self.head, self.base]:
            for kind in ["checks", "packages"]:
                with self.subTest(kind=kind, revision=revision is self.head):
                    saved = copy.deepcopy(revision)
                    revision["ownership"][SYSTEMS[0]][kind].pop(next(iter(
                        revision["ownership"][SYSTEMS[0]][kind])))
                    with self.assertRaisesRegex(ValueError, "unowned exports"):
                        self.select([])
                    revision.clear()
                    revision.update(saved)
            saved = copy.deepcopy(revision)
            revision["tests"]["include"].pop()
            with self.assertRaisesRegex(ValueError, "missing exports"):
                self.select([])
            revision.clear()
            revision.update(saved)

    def test_invalid_duplicate_or_wrong_tier_matrix_targets_fail(self):
        for change in ["attribute", "type", "system", "duplicate", "tier"]:
            with self.subTest(change=change):
                head = copy.deepcopy(self.head)
                row = head["tests"]["include"][0]
                if change == "attribute":
                    row["attr"] = 'checks.x86_64-linux."different"'
                elif change == "type":
                    row["type"] = "packages"
                elif change == "system":
                    del row["system"]
                elif change == "duplicate":
                    head["tests"]["include"].append(row)
                else:
                    head["tests"]["include"] += head["isoTests"]["include"]
                    head["isoTests"]["include"] = []
                with self.assertRaises(ValueError):
                    self.select([], head=head)

    def test_invalid_metadata_fails_instead_of_falling_back(self):
        for value in [{}, {"ownership": {}}, {"ownership": {SYSTEMS[0]: {}}}]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                selection.select(self.head, [], value)
        for field, value in [("source", "/outside.nix"), ("directory", "../other"),
                             ("source", "modules/other/file.nix"), ("module", "")]:
            with self.subTest(field=field, value=value):
                base = copy.deepcopy(self.base)
                base["ownership"][SYSTEMS[0]]["checks"]["example"][field] = value
                with self.assertRaisesRegex(ValueError, "Invalid ownership"):
                    self.select([], base=base)

    def test_plain_and_quoted_attributes_are_accepted(self):
        for tier, kind in selection.KINDS.items():
            for row in self.head[tier]["include"]:
                row["attr"] = f'{kind}.{row["system"]}.{row["name"]}'
        self.assertEqual(self.select(["flake.lock"])[0]["tests"], self.head["tests"])

    def test_summary_records_targets_reasons_and_removed_outputs(self):
        matrices, reasons, retired = self.select(["modules/example/default.nix"])
        text = selection.summary(matrices, reasons, retired)
        self.assertIn("**example-tool**", text)
        self.assertIn("aarch64-linux", text)
        self.assertIn("modules/example/default.nix", text)
        matrices, reasons, _ = self.select([])
        text = selection.summary(matrices, reasons, {("checks", SYSTEMS[0], "retired")})
        self.assertIn("No tests selected", text)
        self.assertIn("No packages selected", text)
        self.assertIn("retired", text)

    def test_cli_emits_both_explicit_selection_flags_and_diagnostics(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for revision in ["base", "head"]:
                (root / f"{revision}.json").write_text(json.dumps(self.head))
            args = [str(SCRIPTS / "select-tests.py"), "--base", "base", "--head", "head",
                    "--base-json", str(root / "base.json"), "--head-json", str(root / "head.json"),
                    "--github-output", str(root / "output"), "--summary", str(root / "summary"),
                    "--selection-json", str(root / "selected.json")]
            with patch.object(sys, "argv", args), patch.object(selection, "changed_paths", return_value=[]), \
                    patch("builtins.print"):
                selection.main()
            output = (root / "output").read_text()
            self.assertIn("packagesSelected=false\n", output)
            self.assertIn("testsSelected=false\n", output)
            self.assertIn('packagesMatrix={"include":[]}\n', output)
            self.assertIn("No packages selected", (root / "summary").read_text())
            self.assertEqual(json.loads((root / "selected.json").read_text()),
                             {"packages": {"include": []}, "tests": {"include": []}})


if __name__ == "__main__":
    unittest.main()
