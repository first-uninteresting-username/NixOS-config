# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
import hashlib
import io
import json
import os
from pathlib import Path
import re
import tarfile
from urllib.request import Request, urlopen


def fetch(url):
    headers = {"User-Agent": "nixos-config-ai-usagebar-updater"}
    if url.startswith("https://api.github.com/") and os.environ.get("GH_TOKEN"):
        headers["Authorization"] = f"Bearer {os.environ['GH_TOKEN']}"
    with urlopen(Request(url, headers=headers), timeout=120) as response:
        return response.read()


def update():
    module_dir = Path("modules/ai-usagebar")
    package_file = module_dir / "_packages.nix"
    original = package_file.read_text()
    release = json.loads(fetch("https://api.github.com/repos/akitaonrails/ai-usagebar/releases/latest"))
    tag = release["tag_name"]
    if not re.fullmatch(r"v\d+\.\d+\.\d+", tag):
        raise ValueError(f"Unexpected release tag: {tag}")
    version = tag[1:]
    archive = fetch(f"https://github.com/akitaonrails/ai-usagebar/archive/refs/tags/{tag}.tar.gz")
    with tarfile.open(fileobj=io.BytesIO(archive), mode="r:gz") as source:
        root = f"ai-usagebar-{version}"
        cargo_lock = source.extractfile(f"{root}/Cargo.lock").read()
        metadata = json.load(source.extractfile(f"{root}/gnome-extension/metadata.json"))
    if metadata["uuid"] != "ai-usagebar@akitaonrails.github.io":
        raise ValueError("Extension UUID changed; review integration manually")
    versions = metadata["shell-version"]
    if not versions or not all(isinstance(v, str) and v.isdigit() for v in versions):
        raise ValueError("Unexpected GNOME Shell compatibility metadata")
    replacements = [
        (r'version = "[^"]+";', f'version = "{version}";'),
        (r'sha256 = "[^"]+";', f'sha256 = "{hashlib.sha256(archive).hexdigest()}";'),
        (r'supportedShellVersions = \[[^;]*\];',
         "supportedShellVersions = [" + " ".join(json.dumps(v) for v in versions) + "];"),
    ]
    updated = original
    for pattern, replacement in replacements:
        updated, count = re.subn(pattern, lambda _: replacement, updated)
        if count != 1:
            raise ValueError(f"Expected exactly one match for {pattern}, found {count}")
    # Read and validate every upstream file before changing the working tree.
    (module_dir / "_sources/Cargo.lock").write_bytes(cargo_lock)
    package_file.write_text(updated)
    print(f"ai-usagebar CLI and GNOME extension: {version}")


if __name__ == "__main__":
    update()
