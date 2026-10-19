#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
"""Check multi-architecture updates and preservation of pins on incomplete releases."""

import copy
import json
from pathlib import Path
import tempfile
import unittest

from update import pin_release


class UpdateTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.destination = Path(self.directory.name) / "release.json"
        self.original = '{"version": "old"}\n'
        self.destination.write_text(self.original)
        self.release = {
            "tag_name": "v1.2.3",
            "assets": [
                {
                    "name": f"orchard_1.2.3_linux_{arch}.tar.gz",
                    "digest": f"sha256:{digest}",
                    "browser_download_url": f"https://example.test/{arch}.tar.gz",
                }
                for arch, digest in [("amd64", "00" * 32), ("arm64", "ff" * 32)]
            ],
        }

    def test_updates_both_architectures(self):
        pin_release(self.release, self.destination)
        pin = json.loads(self.destination.read_text())
        self.assertEqual(pin["version"], "1.2.3")
        self.assertEqual(set(pin["sources"]), {"x86_64-linux", "aarch64-linux"})
        self.assertEqual(pin["sources"]["x86_64-linux"]["hash"], "sha256-" + "A" * 43 + "=")
        self.assertEqual(pin["sources"]["aarch64-linux"]["hash"], "sha256-" + "/" * 42 + "8=")

    def test_incomplete_or_invalid_release_keeps_existing_pin(self):
        broken = copy.deepcopy(self.release)
        broken["assets"].pop()
        cases = [broken]
        for digest in [None, "", "sha512:" + "00" * 32, "sha256:garbage"]:
            broken = copy.deepcopy(self.release)
            broken["assets"][1]["digest"] = digest
            cases.append(broken)
        for release in cases:
            with self.subTest(release=release):
                with self.assertRaises(RuntimeError):
                    pin_release(release, self.destination)
                self.assertEqual(self.destination.read_text(), self.original)
                self.assertEqual(list(self.destination.parent.iterdir()), [self.destination])

    def test_current_pin_is_not_rewritten(self):
        pin_release(self.release, self.destination)
        before = self.destination.stat()
        pin_release(self.release, self.destination)
        after = self.destination.stat()
        self.assertEqual((before.st_ino, before.st_mtime_ns), (after.st_ino, after.st_mtime_ns))


if __name__ == "__main__":
    unittest.main()
