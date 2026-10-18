#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
"""Run isolated fixtures against the repository's pinned inputs, without migration."""

import json
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[3]


def evaluate(attribute, system="x86_64-linux"):
    """Capture diagnostics as data so negative fixtures can assert precise failures."""
    expression = (
        "(import ./lib/modules/tests { "
        "inputs = (builtins.getFlake (toString ./.)).inputs; "
        f"system = {json.dumps(system)}; "
        f"}}).{attribute}"
    )
    return subprocess.run(
        ["nix", "eval", "--impure", "--json", "--expr", expression],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )


def require(condition, message, result):
    if not condition:
        raise SystemExit(f"{message}\n{result.stdout}\n{result.stderr}")


for architecture in ("x86_64-linux", "aarch64-linux"):
    result = evaluate("results", architecture)
    require(result.returncode == 0, f"Fixtures failed on {architecture}", result)
    tests = json.loads(result.stdout)
    require(all(tests.values()), f"A fixture returned false on {architecture}", result)
    print(f"{architecture}: {len(tests)} evaluation fixtures passed", flush=True)

# A nonzero exit alone could hide a syntax or fetch failure; require contextual messages.
for case, fragments in {
    "missing": ["host 'test-system'", "module 'example'", "argument 'systemOnly'"],
    "unknown": ["host 'test-home'", "unknown arguments", "misspelled"],
    "type": ["host 'test-home'", "argument 'userName'", "string"],
    "assertion": ["host 'extra-home'", "shared fixture assertion"],
}.items():
    result = evaluate(f"diagnostics.{case}")
    require(result.returncode != 0, f"Expected {case} to fail", result)
    require(
        all(fragment in result.stderr for fragment in fragments),
        f"Incomplete {case} diagnostic",
        result,
    )

result = evaluate("diagnostics.unused")
require(result.returncode == 0, "Unused arguments should only warn", result)
require(
    "host 'test-home': unused arguments: systemOnly" in result.stderr,
    "Missing unused-argument warning",
    result,
)
print("5 diagnostic fixtures passed", flush=True)
