#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
"""Pin the latest Orchard release and GitHub's SHA-256 digests for both Linux assets."""

import base64
import json
import os
from pathlib import Path
import re
import tempfile
import urllib.request


REPOSITORY = "LeafdTK/orchard-releases"
ARCHITECTURES = {"x86_64-linux": "amd64", "aarch64-linux": "arm64"}


def pin_release(release, destination):
    version = release["tag_name"].removeprefix("v")
    assets = {asset["name"]: asset for asset in release["assets"]}
    sources = {}
    for system, architecture in ARCHITECTURES.items():
        name = f"orchard_{version}_linux_{architecture}.tar.gz"
        if name not in assets:
            raise RuntimeError(f"Release {release['tag_name']} is missing {name}")
        asset = assets[name]
        digest = asset.get("digest") or ""
        if not re.fullmatch(r"sha256:[0-9a-fA-F]{64}", digest):
            raise RuntimeError(f"Asset {name} has no valid SHA-256 digest")
        encoded = base64.b64encode(bytes.fromhex(digest.removeprefix("sha256:"))).decode()
        sources[system] = {"url": asset["browser_download_url"], "hash": f"sha256-{encoded}"}

    # Resolve both assets before atomically replacing the pin; failures leave it untouched.
    content = json.dumps({"version": version, "sources": sources}, indent=2) + "\n"
    if destination.exists() and destination.read_text() == content:
        print(f"Orchard CLI {version} is already current")
        return
    with tempfile.NamedTemporaryFile(mode="w", dir=destination.parent, delete=False) as output:
        output.write(content)
        temporary = Path(output.name)
    temporary.chmod(0o644)
    temporary.replace(destination)
    print(f"Pinned Orchard CLI {version} for both Linux architectures")


def main():
    headers = {"Accept": "application/vnd.github+json", "User-Agent": "orchard-cli-updater"}
    token = os.environ.get("GH_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(
        f"https://api.github.com/repos/{REPOSITORY}/releases/latest", headers=headers
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        release = json.load(response)
    pin_release(release, Path(__file__).with_name("release.json"))


if __name__ == "__main__":
    main()
