#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
"""Pin the latest published release's Debian binaries for both Linux architectures."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import urllib.request


REPOSITORY = "Flow-Tube/Flow-Desktop"
ARCHITECTURES = {"x86_64-linux": "amd64", "aarch64-linux": "arm64"}


def main():
    headers = {"Accept": "application/vnd.github+json", "User-Agent": "flow-desktop-updater"}
    token = os.environ.get("GH_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(
        f"https://api.github.com/repos/{REPOSITORY}/releases/latest", headers=headers
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        release = json.load(response)

    version = release["tag_name"].removeprefix("v")
    assets = {asset["name"]: asset for asset in release["assets"]}
    sources = {}
    for system, architecture in ARCHITECTURES.items():
        name = f"Flow_{version}_linux_{architecture}.deb"
        if name not in assets:
            raise RuntimeError(f"Release {release['tag_name']} is missing {name}")
        url = assets[name]["browser_download_url"]
        result = subprocess.run(
            ["nix", "store", "prefetch-file", "--json", "--hash-type", "sha256", url],
            check=True, capture_output=True, text=True,
        )
        sources[system] = {"url": url, "hash": json.loads(result.stdout)["hash"]}

    # Replace the pin only after both downloads succeed; never publish a partial update.
    destination = Path(__file__).with_name("release.json")
    content = json.dumps({"version": version, "sources": sources}, indent=2) + "\n"
    if destination.exists() and destination.read_text() == content:
        print(f"Flow Desktop {version} is already current")
        return
    with tempfile.NamedTemporaryFile(mode="w", dir=destination.parent, delete=False) as output:
        output.write(content)
        temporary = Path(output.name)
    temporary.chmod(0o644)
    temporary.replace(destination)
    print(f"Pinned Flow Desktop {version} for both Linux architectures")


if __name__ == "__main__":
    main()
