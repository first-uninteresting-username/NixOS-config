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
    "persistence-without-user-state": ("preservation-persistence", "AssertionError", "persistence-user-state"),
    "upgrade": ("update", "AssertionError", "upgrade-failure-propagation"),
}


class ProofError(RuntimeError):
    pass


@dataclass
class BuildResult:
    returncode: int
    output: str


def assertion_failed(output, exception, marker):
    """Accept the expected traceback, not source text or unrelated build failures."""
    clean = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", output)
    log_line = re.compile(r"^[ \t]*(?P<prefix>[A-Za-z0-9+._?=-]*>)[ ]?(?P<text>.*)$")
    expected = re.compile(rf"{exception}: CHECKS_V2_REGRESSION:{re.escape(marker)}"
                          r"(?:[ \t]*|:[^\r\n]*)$")
    frame = re.compile(r'File "[^"]+", line [0-9]+(?:, in .*)?$')
    terminal = re.compile(r"[A-Za-z_][\w.]*:.*$")
    tracebacks = {}
    for line in clean.splitlines():
        match = log_line.fullmatch(line)
        prefix = match.group("prefix") if match else ""
        text = match.group("text") if match else line
        if text.strip() == "Traceback (most recent call last):":
            tracebacks[prefix] = False
        elif prefix in tracebacks and frame.fullmatch(text.strip()):
            tracebacks[prefix] = True
        elif expected.fullmatch(text.rstrip()) and tracebacks.get(prefix, False):
            return True
        elif terminal.fullmatch(text.rstrip()):
            tracebacks.pop(prefix, None)
    return False


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
    if negative.returncode != 1:
        raise ProofError(f"{case}: negative Nix build was interrupted or returned an unexpected "
                         f"exit status ({negative.returncode})")
    if not assertion_failed(negative.output, exception, marker):
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
