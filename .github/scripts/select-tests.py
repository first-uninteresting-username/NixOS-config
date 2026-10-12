#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
"""Select behavioral checks from the complete PR diff, including both rename paths."""

import argparse
import fnmatch
import json
from pathlib import Path
import subprocess


def changed_paths(base, head, cwd=None):
    """Compare against the merge base; disabling renames retains old and new paths."""
    result = subprocess.run(
        ["git", "diff", "--no-renames", "--name-only", "-z", f"{base}...{head}", "--"],
        cwd=cwd, check=True, capture_output=True,
    )
    return [path.decode("utf-8", errors="surrogateescape")
            for path in result.stdout.split(b"\0") if path]


def matches(path, patterns):
    return any(fnmatch.fnmatchcase(path, pattern) for pattern in patterns)


def select(matrix, paths, mapping, mode="pr", iso="both"):
    rows = matrix["include"]
    names = {row["name"] for row in rows}
    reasons = {}
    if mode == "iso":
        wanted = {"iso-john", "iso-wall-e"} if iso == "both" else {f"iso-{iso}"}
        missing = wanted - names
        if missing:
            raise ValueError(f"ISO checks missing from matrix: {sorted(missing)}")
        reasons = {name: [f"on-demand ISO selection: {iso}"] for name in wanted}
    elif mode == "weekly":
        if not names:
            raise ValueError("Weekly complete suite cannot have an empty test matrix")
        reasons = {name: ["weekly complete suite"] for name in names}
    else:
        # ISO checks run with their corresponding builds, never in the ordinary PR tier.
        names = {name for name in names if not name.startswith("iso-")}
        unknown = names - mapping["tests"].keys()
        if unknown:
            raise ValueError(f"Tests need an explicit dependency mapping: {sorted(unknown)}")
        for path in sorted(set(paths)):
            if matches(path, mapping["shared"]):
                for name in names:
                    reasons.setdefault(name, []).append(f"{path}: shared dependency or infrastructure")
                continue
            classified = False
            for name, patterns in mapping["tests"].items():
                if matches(path, patterns):
                    # module-docs covers option freshness but cannot classify behavioral coverage.
                    if name != "module-docs":
                        classified = True
                    if name in names:
                        reasons.setdefault(name, []).append(f"{path}: mapped to {name}")
            if not classified and matches(path, mapping["configuration"]):
                # Docs generator changes are explicitly covered by their own retained check.
                if matches(path, ["packages/docs/**"]):
                    continue
                for name in names:
                    reasons.setdefault(name, []).append(f"{path}: unclassified configuration fallback")
    selected = {"include": [row for row in rows if row["name"] in reasons]}
    return selected, reasons


def summary(matrix, reasons):
    lines = ["## Selected behavioral tests", ""]
    if not matrix["include"]:
        return "\n".join(lines + ["No tests selected: the diff has no affected behavioral dependencies.", ""])
    for name in sorted(reasons):
        systems = sorted({row["system"] for row in matrix["include"] if row["name"] == name})
        lines.append(f"- **{name}** ({', '.join(systems)}):")
        for reason in reasons[name]:
            # JSON escaping keeps unusual filenames from becoming multiline Markdown instructions.
            lines.append(f"  - {json.dumps(reason, ensure_ascii=True)}")
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base")
    parser.add_argument("--head")
    parser.add_argument("--matrix-json", type=Path, required=True)
    parser.add_argument("--mode", choices=["pr", "weekly", "iso"], default="pr")
    parser.add_argument("--iso", choices=["john", "wall-e", "both"], default="both")
    parser.add_argument("--github-output", type=Path)
    parser.add_argument("--summary", type=Path)
    args = parser.parse_args()
    if args.mode == "pr" and not (args.base and args.head):
        parser.error("PR selection requires --base and --head")
    mapping = json.loads(Path(__file__).with_name("test-map.json").read_text())
    matrix = json.loads(args.matrix_json.read_text())
    paths = changed_paths(args.base, args.head) if args.mode == "pr" else []
    selected, reasons = select(matrix, paths, mapping, args.mode, args.iso)
    encoded = json.dumps(selected, separators=(",", ":"))
    print(encoded)
    if args.github_output:
        with args.github_output.open("a") as output:
            output.write(f"testsMatrix={encoded}\n")
            output.write(f"testsSelected={str(bool(selected['include'])).lower()}\n")
    if args.summary:
        with args.summary.open("a") as output:
            output.write(summary(selected, reasons))


if __name__ == "__main__":
    main()
