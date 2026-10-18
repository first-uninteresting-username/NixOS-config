#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
"""Merge strictly scoped updates using trusted policy and checks on the current revision."""

import argparse
import base64
import copy
import json
import os
from pathlib import Path
import re
import subprocess
import urllib.error
import urllib.request


AGGREGATE = "all-systems-passed"
ACTIONS_APP = 15368
ACTION_BOT_ID = 41898282
HASH_FILE = "modules/programs-desktop/_flow-desktop/release.json"


def same_repository(source, repository):
    repository_id = repository.get("id")
    return (type(repository_id) is int and repository_id > 0 and isinstance(source, dict)
            and type(source.get("id")) is int and source["id"] == repository_id)


def allowed_identity(author, repository):
    """Bind trusted authors and workflow actors to authenticated GitHub account IDs."""
    author = author or {}
    owner = repository.get("owner") or {}
    if type(author.get("id")) is not int or author["id"] <= 0:
        return False, "author identity is missing or invalid"
    if (author.get("type") == "User" and owner.get("type") == "User"
            and type(owner.get("id")) is int
            and owner["id"] > 0 and author["id"] == owner["id"]):
        return True, "verified repository owner"
    if (author.get("id") == ACTION_BOT_ID and author.get("type") == "Bot"
            and author.get("login") == "github-actions[bot]"):
        return True, "verified GitHub Actions bot"
    return False, "author is not the repository owner or verified GitHub Actions bot"


def allowed_update(pr, repository):
    """Trust same-repository PRs from its personal owner or the verified Actions bot."""
    repository_id = repository.get("id")
    if type(repository_id) is not int or repository_id <= 0:
        return False, "repository identity is missing"
    for side in ["base", "head"]:
        if not same_repository(pr.get(side, {}).get("repo"), repository):
            return False, "fork or missing repository identity requires manual review"
    return allowed_identity(pr.get("user"), repository)


def allowed_workflow(run, repository):
    for field in ["repository", "head_repository"]:
        if not same_repository(run.get(field), repository):
            return False, "checked workflow has a fork or missing repository identity"
    return allowed_identity(run.get("actor"), repository)


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def valid_hash(value):
    if not isinstance(value, str) or not value.startswith("sha256-"):
        return False
    try:
        decoded = base64.b64decode(value[7:], validate=True)
    except (ValueError, TypeError):
        return False
    return len(decoded) == 32 and base64.b64encode(decoded).decode() == value[7:]


def source_hash_only(old, new):
    """Allow only valid hash-leaf changes while preserving URLs, versions, and shape."""
    try:
        before = json.loads(old, object_pairs_hook=unique_object)
        after = json.loads(new, object_pairs_hook=unique_object)
        if not isinstance(before, dict) or not isinstance(after, dict):
            return False
        old_sources = before["sources"]
        new_sources = after["sources"]
        if not isinstance(old_sources, dict) or not old_sources or old_sources.keys() != new_sources.keys():
            return False
        scrubbed = copy.deepcopy(after)
        changed = False
        for system, source in old_sources.items():
            new_source = new_sources[system]
            if not isinstance(source, dict) or not isinstance(new_source, dict):
                return False
            if not valid_hash(source["hash"]) or not valid_hash(new_source["hash"]):
                return False
            changed |= source["hash"] != new_source["hash"]
            scrubbed["sources"][system]["hash"] = source["hash"]
        # Python equality treats true, 1 and 1.0 as equal; source metadata types must stay fixed.
        return changed and (json.dumps(scrubbed, sort_keys=True, allow_nan=False)
                            == json.dumps(before, sort_keys=True, allow_nan=False))
    except (ValueError, TypeError, KeyError, AttributeError):
        return False


def eligible(changes):
    """changes contains (status, path, old bytes, new bytes), read without checking out PR code."""
    if not changes:
        return False, "empty diff"
    for status, path, old, new in changes:
        if status != "M":
            return False, f"{path}: additions, deletions and renames are not automatic updates"
        if path == "flake.lock":
            try:
                if not isinstance(json.loads(new, object_pairs_hook=unique_object), dict):
                    return False, "flake.lock must remain a JSON object"
            except (ValueError, TypeError):
                return False, "flake.lock is not valid JSON"
        elif path == HASH_FILE and source_hash_only(old, new):
            continue
        else:
            return False, f"{path}: not a supported package source-hash-only update"
    return True, "diff contains only flake.lock and/or validated package source hashes"


def required_contexts(branch, rules):
    """Read both classic protection and active rulesets using non-administrative APIs."""
    requirements = {(AGGREGATE, ACTIONS_APP)}
    classic = branch.get("protection", {}).get("required_status_checks", {})
    checks = classic.get("checks", [])
    requirements.update((item["context"], item.get("app_id")) for item in checks)
    checked = {item["context"] for item in checks}
    requirements.update((name, None) for name in classic.get("contexts", []) if name not in checked)
    for rule in rules:
        if rule["type"] == "required_status_checks":
            requirements.update((item["context"], item.get("integration_id"))
                                for item in rule["parameters"]["required_status_checks"])
    return requirements


def check_failures(sha, check_runs, statuses, required, suite_id):
    problems = []
    for context, app_id in sorted(required, key=lambda item: (item[0], item[1] or 0)):
        matching_checks = [check for check in check_runs
                           if check["name"] == context and check["head_sha"] == sha
                           and (app_id in (None, -1) or check["app"]["id"] == app_id)]
        matching_statuses = [status for status in statuses if status["context"] == context]
        if app_id not in (None, -1):
            matching_statuses = []  # Legacy commit statuses cannot establish the required app identity.
        latest_check = max(matching_checks, key=lambda item: item["id"], default=None)
        latest_status = max(matching_statuses, key=lambda item: item["id"], default=None)
        if latest_check is None and latest_status is None:
            problems.append(f"{context}: missing on {sha}")
            continue
        # If both APIs contain the context, both latest records must be successful.
        if latest_check and (latest_check["status"] != "completed"
                             or latest_check["conclusion"] != "success"):
            problems.append(f"{context}: check is {latest_check['status']}/{latest_check['conclusion']}")
        if latest_status and latest_status["state"] != "success":
            problems.append(f"{context}: status is {latest_status['state']}")
        if context == AGGREGATE:
            triggering = [check for check in matching_checks if check["check_suite"]["id"] == suite_id]
            latest_trigger = max(triggering, key=lambda item: item["id"], default=None)
            if (latest_trigger is None or latest_trigger["status"] != "completed"
                    or latest_trigger["conclusion"] != "success"):
                problems.append(f"{context}: no successful aggregate from the completed triggering run")
    return problems


class GitHub:
    def __init__(self, repository):
        self.root = f"https://api.github.com/repos/{repository}"

    def request(self, path, method="GET", body=None):
        request = urllib.request.Request(
            self.root + path, method=method,
            data=json.dumps(body).encode() if body is not None else None,
            headers={"Authorization": f"Bearer {os.environ['GH_TOKEN']}",
                     "Accept": "application/vnd.github+json",
                     "X-GitHub-Api-Version": "2022-11-28", "Content-Type": "application/json"},
        )
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)

    def pages(self, path, key=None):
        result = []
        for page in range(1, 1001):
            separator = "&" if "?" in path else "?"
            response = self.request(f"{path}{separator}per_page=100&page={page}")
            items = response[key] if key else response
            result.extend(items)
            if len(items) < 100:
                return result
        raise RuntimeError("API pagination exceeded limit")


def git(*args):
    return subprocess.run(["git", *args], check=True, capture_output=True).stdout


def revision_changes(base, head):
    merge_base = git("merge-base", base, head).decode().strip()
    raw = git("diff", "--no-renames", "--raw", "--no-abbrev", "-z", merge_base, head, "--").split(b"\0")
    result = []
    for index in range(0, len(raw) - 1, 2):
        old_mode, new_mode, old_object, new_object, status = raw[index].decode().split()
        old_mode = old_mode.removeprefix(":")
        path = raw[index + 1].decode("utf-8", errors="surrogateescape")
        old = git("show", f"{merge_base}:{path}") if status != "A" else None
        new = git("show", f"{head}:{path}") if status != "D" else None
        if status == "M" and (old_mode != new_mode or new_mode != "100644"
                              or old_object == new_object):
            status = "mode"
        result.append((status, path, old, new))
    return result


def process(api, run, pr, default_branch, repository):
    """Recheck identity, revisions, and required statuses before merging the exact head."""
    number = pr["number"]
    if pr["state"] != "open" or pr["draft"] or pr["base"]["ref"] != default_branch:
        return f"PR #{number}: not an open, ready PR against {default_branch}"
    allowed, reason = allowed_update(pr, repository)
    if not allowed:
        return f"PR #{number}: manual merge required ({reason})"
    allowed, reason = allowed_workflow(run, repository)
    if not allowed:
        return f"PR #{number}: manual merge required (checked workflow identity: {reason})"
    sha = pr["head"]["sha"]
    if sha != run["head_sha"]:
        return f"PR #{number}: completed run is for a superseded revision"
    if not re.fullmatch(r"[0-9a-f]{40}", sha):
        raise ValueError("unexpected head SHA")
    git("fetch", "--no-tags", "origin", f"refs/heads/{default_branch}")
    base = git("rev-parse", "FETCH_HEAD").decode().strip()
    git("fetch", "--no-tags", "origin", f"refs/pull/{number}/head")
    if git("rev-parse", "FETCH_HEAD").decode().strip() != sha:
        return f"PR #{number}: head changed while fetching; leaving it open"
    allowed, reason = eligible(revision_changes(base, sha))
    if not allowed:
        return f"PR #{number}: manual merge required ({reason})"
    branch = api.request(f"/branches/{default_branch}")
    rules = api.request(f"/rules/branches/{default_branch}")
    checks = api.pages(f"/commits/{sha}/check-runs?filter=all", "check_runs")
    statuses = api.pages(f"/commits/{sha}/statuses")
    problems = check_failures(sha, checks, statuses, required_contexts(branch, rules), run["check_suite_id"])
    if problems:
        return f"PR #{number}: checks prevent merging ({'; '.join(problems)})"
    current = api.request(f"/pulls/{number}")
    if (current["head"]["sha"] != sha or current["state"] != "open" or current["draft"]
            or current["base"]["ref"] != default_branch or current["base"]["sha"] != base):
        return f"PR #{number}: PR changed while checking; leaving it open"
    allowed, reason = allowed_update(current, repository)
    if not allowed:
        return f"PR #{number}: update trust changed while checking; leaving it open ({reason})"
    # The SHA precondition closes the final race; GitHub still enforces all branch protection.
    response = api.request(f"/pulls/{number}/merge", "PUT", {"sha": sha, "merge_method": "merge"})
    return f"PR #{number}: {response['message']} (revision {sha})"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--run-id", type=int, required=True)
    parser.add_argument("--summary", type=Path)
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", args.repository):
        parser.error("invalid repository name")
    api = GitHub(args.repository)
    repository = api.request("")
    default_branch = repository["default_branch"]
    run = api.request(f"/actions/runs/{args.run_id}")
    workflow = api.request(f"/actions/workflows/{run['workflow_id']}")
    if (run["event"] != "pull_request" or run["status"] != "completed"
            or run["conclusion"] != "success" or workflow["path"] != ".github/workflows/flake-build.yaml"):
        raise SystemExit("Run is not a successful completed pull-request tier workflow")
    results = []
    for associated in api.pages(f"/commits/{run['head_sha']}/pulls"):
        try:
            pr = api.request(f"/pulls/{associated['number']}")
            results.append(process(api, run, pr, default_branch, repository))
        except urllib.error.HTTPError as error:
            # Missing authorization or protection restrictions must never turn into a bypass.
            results.append(f"PR #{associated['number']}: GitHub refused the operation (HTTP {error.code})")
    if not results:
        results.append("No current pull request associated with this revision")
    report = "## Dependency update merge policy\n\n" + "\n".join(f"- {line}" for line in results) + "\n"
    print(report)
    if args.summary:
        with args.summary.open("a") as output:
            output.write(report)


if __name__ == "__main__":
    main()
