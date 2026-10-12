#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
"""Build a positive check, then require its deliberate regression's precise assertion failure."""

import argparse
from dataclasses import dataclass
from pathlib import Path
import re
import subprocess


CASES = {
    "persistence-without-user-state": ("persistence", "AssertionError", "persistence-user-state"),
    "networkmanager-secrets-without-reload": ("networkmanager-secrets", "AssertionError",
                                            "networkmanager-profile-load"),
    "gnome-session": ("gnome-session", "AssertionError", "gnome-home-manager-gestures"),
    "upgrade": ("upgrade", "AssertionError", "upgrade-failure-propagation"),
    "printing-discovery": ("printing-discovery", "AssertionError", "printing-mdns-discovery"),
    "iso-john": ("iso-john", "RuntimeError", "iso-john-boot"),
    "iso-wall-e": ("iso-wall-e", "RuntimeError", "iso-wall-e-boot"),
}


class ProofError(RuntimeError):
    pass


@dataclass
class BuildResult:
    returncode: int
    output: str


def build(command):
    print("+ " + " ".join(command), flush=True)
    try:
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                   text=True, errors="replace")
    except OSError as error:
        raise ProofError(f"Cannot start the build: {error}") from error
    output = []
    with process.stdout:
        for line in process.stdout:
            print(line, end="", flush=True)
            output.append(line)
    return BuildResult(process.wait(), "".join(output))


def prove(case, system="x86_64-linux", runner=build):
    normal, exception, marker = CASES[case]
    positive = runner(["nix", "build", f".#checks.{system}.{normal}", "--no-link", "-L"])
    if positive.returncode != 0:
        raise ProofError(f"Normal {normal} check failed; a failing baseline cannot prove a regression")
    negative = runner(["nix", "build", f".#regressionChecks.{system}.{case}", "--no-link", "-L"])
    if negative.returncode == 0:
        raise ProofError(f"Deliberate regression {case} unexpectedly passed")
    # Driver prefixes are allowed, but only a terminal Python exception line counts.
    # Merely logging the test script, subtest name or an unrelated failed dependency cannot pass.
    expected = re.compile(rf"\b{exception}: CHECKS_V2_REGRESSION:{re.escape(marker)}"
                          r"(?=[:\s]|$)[^\r\n]*$", re.MULTILINE)
    if not expected.search(negative.output):
        raise ProofError(f"{case} failed without its expected assertion; environment, evaluation and "
                         "dependency failures do not count as regression proof")
    return f"{case}: normal {normal} passed; deliberate regression failed at {marker}"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--case", choices=sorted(CASES), required=True)
    parser.add_argument("--system", choices=["x86_64-linux"], default="x86_64-linux")
    parser.add_argument("--summary", type=Path)
    args = parser.parse_args()
    try:
        outcome = prove(args.case, args.system)
    except ProofError as error:
        outcome = f"Regression proof failed: {error}"
        print(f"::error::{outcome}")
        status = 1
    else:
        print(outcome)
        status = 0
    if args.summary:
        with args.summary.open("a") as output:
            output.write(f"### Regression proof: {args.case}\n\n{outcome}\n")
    raise SystemExit(status)


if __name__ == "__main__":
    main()
