#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
"""Select checks and packages from base/head module ownership and the complete PR diff."""

import argparse
import fnmatch
import json
from pathlib import Path
import re
import subprocess


SHARED = [
    "flake.nix", "flake.lock", "lib/**", "arguments/**", "hosts/**",
    "github-actions/**", ".github/scripts/**", ".github/workflows/**", ".github/nix.conf",
    "devenv.nix", "devenv.yaml", "checks/**", "modules/user/**", "modules/home-manager/**",
]
KINDS = {"packages": "packages", "tests": "checks", "isos": "packages", "isoTests": "checks"}


def changed_paths(base, head, cwd=None):
    """Compare against the merge base; disabling renames retains old and new paths."""
    result = subprocess.run(
        ["git", "diff", "--no-renames", "--name-only", "-z", f"{base}...{head}", "--"],
        cwd=cwd, check=True, capture_output=True,
    )
    return [path.decode("utf-8", errors="surrogateescape")
            for path in result.stdout.split(b"\0") if path]


def matrix_targets(matrix, kind):
    if not isinstance(matrix, dict) or not isinstance(matrix.get("include"), list):
        raise ValueError(f"Invalid {kind} matrix")
    targets = {}
    for row in matrix["include"]:
        if not isinstance(row, dict):
            raise ValueError(f"Invalid {kind} matrix row: {row}")
        name, system = row.get("name"), row.get("system")
        if not isinstance(name, str) or not name or not isinstance(system, str) or not system:
            raise ValueError(f"Invalid {kind} matrix target: {row}")
        attributes = {f"{kind}.{system}.{json.dumps(name, ensure_ascii=False)}"}
        if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_'\-]*", name):
            attributes.add(f"{kind}.{system}.{name}")
        if row.get("attr") not in attributes or row.get("type") != kind:
            raise ValueError(f"Matrix attribute/type does not match its target: {row}")
        key = (kind, system, name)
        if key in targets:
            raise ValueError(f"Duplicate matrix target: {key}")
        targets[key] = row
    return targets


def relative_path(path, directory=False):
    return (isinstance(path, str) and bool(path)
            and ((directory and path == ".") or
                 all(part not in {"", ".", ".."} for part in path.split("/"))))


def within(path, directory):
    return directory == "." or path.startswith(directory + "/")


def is_iso(key):
    kind, system, name = key
    return (name.startswith("iso-") if kind == "checks" else
            system == "x86_64-linux" and name in {"host-john", "host-wall-e"})


def validate_snapshot(snapshot):
    """Require a bijection between per-system ownership and all exported CI targets."""
    if not isinstance(snapshot, dict) or not isinstance(snapshot.get("ownership"), dict):
        raise ValueError("Missing ownership metadata")
    owners = {}
    if not snapshot["ownership"]:
        raise ValueError("Empty ownership metadata")
    for system, metadata in snapshot["ownership"].items():
        if (not isinstance(metadata, dict) or type(metadata.get("schemaVersion")) is not int
                or metadata["schemaVersion"] != 1 or metadata.get("system") != system):
            raise ValueError(f"Invalid ownership schema/system: {system}")
        for kind in {"packages", "checks"}:
            entries = metadata.get(kind)
            if not isinstance(entries, dict):
                raise ValueError(f"Missing {kind} ownership: {system}")
            for name, owner in entries.items():
                if (not isinstance(owner, dict) or not isinstance(owner.get("module"), str)
                        or not owner["module"] or not relative_path(owner.get("source"))
                        or not relative_path(owner.get("directory"), directory=True)
                        or not within(owner["source"], owner["directory"])
                        or not isinstance(owner.get("extraFiles"), list)
                        or not all(relative_path(path) for path in owner["extraFiles"])
                        or (kind == "packages" and owner["extraFiles"])):
                    raise ValueError(f"Invalid ownership for {kind}.{system}.{name}: {owner}")
                owners[(kind, system, name)] = owner
    targets = {}
    for tier, kind in KINDS.items():
        rows = matrix_targets(snapshot.get(tier), kind)
        for key, row in rows.items():
            if is_iso(key) != (tier in {"isos", "isoTests"}):
                raise ValueError(f"Target is in the wrong ISO tier: {key}")
            if key in targets:
                raise ValueError(f"Duplicate matrix target: {key}")
            targets[key] = row
    if owners.keys() != targets.keys():
        raise ValueError("Matrices and ownership disagree: "
                         f"unowned exports={sorted(targets.keys() - owners.keys())}, "
                         f"missing exports={sorted(owners.keys() - targets.keys())}")
    return owners


def select(head, paths, base=None, mode="pr"):
    owners = validate_snapshot(head)
    previous = validate_snapshot(base) if base is not None else {}
    available = {key for key in owners if not is_iso(key)}
    reasons = {}
    retired = set()

    def add(key, reason):
        if key in available:
            reasons.setdefault(key, set()).add(reason)
        elif key not in owners and not is_iso(key):
            retired.add(key)

    if mode == "weekly" or base is None:
        reason = "full run" if mode == "weekly" else "base predates ownership metadata: full suite"
        for key in available:
            add(key, reason)
    else:
        for path in sorted(set(paths)):
            shared = any(fnmatch.fnmatchcase(path, pattern) for pattern in SHARED)
            # New modules without outputs add no behavioral checks. Unknown shared Nix
            # sources outside modules remain conservative, as in checks v2.
            shared |= path.endswith(".nix") and not path.startswith("modules/")
            if shared:
                for key in available:
                    add(key, f"{path}: shared dependency or infrastructure")
                continue
            for revision, entries in [("base", previous), ("head", owners)]:
                for key, owner in entries.items():
                    if within(path, owner["directory"]):
                        reason = f"{path}: {revision} module directory ({owner['module']})"
                        add(key, reason)
                        # Follow the module when a declaration or its outputs move/rename.
                        for current, current_owner in owners.items():
                            if current_owner["module"] == owner["module"]:
                                add(current, reason)
                    elif path in owner["extraFiles"]:
                        add(key, f"{path}: {revision} extra watched file")
    matrices = {tier: {"include": [row for row in head[tier]["include"]
                                  if (kind, row["system"], row["name"]) in reasons]}
                for tier, kind in [("packages", "packages"), ("tests", "checks")]}
    return matrices, reasons, retired


def select_iso(matrix, iso):
    targets = matrix_targets(matrix, "checks")
    wanted = {"iso-john", "iso-wall-e"} if iso == "both" else {f"iso-{iso}"}
    missing = wanted - {key[2] for key in targets}
    if missing:
        raise ValueError(f"ISO checks missing from matrix: {sorted(missing)}")
    return {"include": [row for row in matrix["include"] if row["name"] in wanted]}


def summary(matrices, reasons, retired):
    lines = []
    for tier, kind in [("packages", "packages"), ("tests", "checks")]:
        lines += [f"## Selected {tier}", ""]
        if not matrices[tier]["include"]:
            lines += [f"No {tier} selected: no affected exported targets.", ""]
        for row in matrices[tier]["include"]:
            key = (kind, row["system"], row["name"])
            lines.append(f"- **{row['name']}** ({row['system']}):")
            for reason in sorted(reasons[key]):
                # Escape unusual filenames so they cannot become multiline Markdown.
                lines.append(f"  - {json.dumps(reason, ensure_ascii=True)}")
    if retired:
        lines += ["", "Removed targets have no head export to build:"]
        lines += [f"- {json.dumps('.'.join(key))}" for key in sorted(retired)]
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base")
    parser.add_argument("--head")
    parser.add_argument("--head-json", type=Path)
    parser.add_argument("--base-json", type=Path)
    parser.add_argument("--matrix-json", type=Path)
    parser.add_argument("--selection-json", type=Path)
    parser.add_argument("--mode", choices=["pr", "weekly", "iso"], default="pr")
    parser.add_argument("--iso", choices=["john", "wall-e", "both"], default="both")
    parser.add_argument("--github-output", type=Path)
    parser.add_argument("--summary", type=Path)
    args = parser.parse_args()
    if args.mode == "iso":
        if not args.matrix_json:
            parser.error("ISO selection requires --matrix-json")
        matrix = select_iso(json.loads(args.matrix_json.read_text()), args.iso)
        print(json.dumps(matrix, separators=(",", ":")))
        if args.summary:
            with args.summary.open("a") as output:
                output.write(f"Selected ISO smoke checks: {args.iso}.\n")
        return
    if not args.head_json:
        parser.error("Selection requires --head-json")
    if args.mode == "pr" and not (args.base and args.head and args.base_json):
        parser.error("PR selection requires --base, --head and --base-json")
    head = json.loads(args.head_json.read_text())
    base = json.loads(args.base_json.read_text()) if args.mode == "pr" else None
    paths = changed_paths(args.base, args.head) if args.mode == "pr" else []
    matrices, reasons, retired = select(head, paths, base, args.mode)
    encoded = json.dumps(matrices, separators=(",", ":"))
    print(encoded)
    if args.selection_json:
        args.selection_json.write_text(encoded + "\n")
    if args.github_output:
        with args.github_output.open("a") as output:
            for tier in ("packages", "tests"):
                output.write(f"{tier}Matrix={json.dumps(matrices[tier], separators=(',', ':'))}\n")
                output.write(f"{tier}Selected={str(bool(matrices[tier]['include'])).lower()}\n")
    if args.summary:
        with args.summary.open("a") as output:
            output.write(summary(matrices, reasons, retired))


if __name__ == "__main__":
    main()
