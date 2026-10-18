#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
"""Require every planned tier to succeed and only accept explicitly omitted tiers."""

import argparse


def failures(jobs, selected_tests, weekly, prove_regressions=False, selected_packages=True):
    expected = {
        "basic": "success", "discover": "success",
        "packages": "success" if selected_packages or weekly else "skipped",
        "tests": "success" if selected_tests or weekly else "skipped",
        "hosts": "success" if weekly else "skipped",
        "isos": "success" if weekly else "skipped",
        "regressions": "success" if prove_regressions else "skipped",
    }
    return [f"{name}: expected {wanted}, received {jobs.get(name, 'missing')}"
            for name, wanted in expected.items() if jobs.get(name) != wanted]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--job", action="append", default=[])
    parser.add_argument("--selected-packages", choices=["true", "false"], required=True)
    parser.add_argument("--selected-tests", choices=["true", "false"], required=True)
    parser.add_argument("--weekly", choices=["true", "false"], default="false")
    parser.add_argument("--prove-regressions", choices=["true", "false"], default="false")
    args = parser.parse_args()
    jobs = {}
    for job in args.job:
        name, result = job.split("=", 1)
        if name in jobs:
            parser.error(f"duplicate job: {name}")
        jobs[name] = result
    problems = failures(jobs, args.selected_tests == "true", args.weekly == "true",
                        args.prove_regressions == "true", args.selected_packages == "true")
    if problems:
        for problem in problems:
            print(f"::error::{problem}")
        raise SystemExit(1)
    print("All applicable CI tiers succeeded; omitted tiers match the selection plan.")


if __name__ == "__main__":
    main()
