#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
"""Block until the required check finishes on a pull request's exact head commit.

Exit codes: 0 passed, 1 failed, 2 timed out, 3 PR no longer open, 4 head commit moved.
"""

import argparse
import json
import subprocess
import sys
import time

REQUIRED_CHECK = "all-systems-passed"
ACTIONS_APP = 15368


def gh(*args, attempts=5):
    """Run gh and parse JSON, retrying transient network or API errors."""
    for attempt in range(attempts):
        result = subprocess.run(["gh", *args], capture_output=True, text=True)
        if result.returncode == 0:
            return json.loads(result.stdout)
        if attempt + 1 < attempts:
            time.sleep(30)
    raise RuntimeError(result.stderr.strip() or f"gh {' '.join(args)} failed")


def log(message):
    print(f"[{time.strftime('%H:%M:%S')}] {message}", flush=True)


def required_run(repo, sha):
    """Return the newest required check run on this exact commit, or None."""
    data = gh("api", f"repos/{repo}/commits/{sha}/check-runs?check_name={REQUIRED_CHECK}")
    runs = [run for run in data["check_runs"] if (run.get("app") or {}).get("id") == ACTIONS_APP]
    return max(runs, key=lambda run: run["started_at"] or "", default=None)


def failed_jobs(repo, sha):
    data = gh("api", f"repos/{repo}/commits/{sha}/check-runs?per_page=100")
    bad = {"failure", "timed_out", "cancelled", "action_required", "startup_failure"}
    return sorted(run["name"] for run in data["check_runs"] if run["conclusion"] in bad)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pr", type=int)
    parser.add_argument("--sha", help="expected head commit; defaults to the current head")
    parser.add_argument("--interval", type=int, default=90, help="seconds between polls")
    parser.add_argument("--timeout", type=int, default=90 * 60, help="seconds before giving up")
    args = parser.parse_args()

    repo = gh("repo", "view", "--json", "nameWithOwner")["nameWithOwner"]
    deadline = time.monotonic() + args.timeout
    sha = args.sha
    last = None

    while True:
        pr = gh("pr", "view", str(args.pr), "--json", "state,headRefOid,url")
        if pr["state"] != "OPEN":
            log(f"PR #{args.pr} is {pr['state']}")
            return 3
        sha = sha or pr["headRefOid"]
        if pr["headRefOid"] != sha:
            log(f"head moved from {sha[:10]} to {pr['headRefOid'][:10]}")
            return 4

        run = required_run(repo, sha)
        state = "not started" if run is None else run["conclusion"] or run["status"]
        if state != last:
            log(f"PR #{args.pr} @ {sha[:10]}: {REQUIRED_CHECK} {state}")
            last = state
        if run is not None and run["status"] == "completed":
            if run["conclusion"] == "success":
                print(f"PASSED {sha}")
                return 0
            print(f"FAILED {sha} {run['html_url']}")
            for name in failed_jobs(repo, sha):
                print(f"  failed: {name}")
            return 1

        if time.monotonic() >= deadline:
            print(f"TIMEOUT {sha} after {args.timeout}s ({state})")
            return 2
        time.sleep(args.interval)


if __name__ == "__main__":
    sys.exit(main())
