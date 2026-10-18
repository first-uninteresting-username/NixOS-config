#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
"""Check rendered host content and file:// navigation without a web server."""

from html.parser import HTMLParser
from pathlib import Path
import sys
from urllib.parse import unquote, urlsplit


source, site = map(Path, sys.argv[1:])
modules = source / "docs/modules"
assert sorted(path.name for path in modules.iterdir()) == [
    "alpha.md", "nixos-only.md", "zeta.md"
]
alpha = (modules / "alpha.md").read_text()
assert "## Module docs" not in alpha
assert "## Imperative steps" in alpha
assert "Alpha setup marker: override." in alpha
assert "documented-home: fixture, 31" in (modules / "zeta.md").read_text()
system_only = (modules / "nixos-only.md").read_text()
assert "Selected NixOS-only documentation marker." in system_only
assert "## Imperative steps" not in system_only
combined = (source / "docs/imperative-steps.md").read_text()
assert combined.index("## alpha") < combined.index("## zeta")
assert "nixos-only" not in combined
assert "The fixture user" in (source / "docs/module-reference.md").read_text()


class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.paths = []
        self.palettes = {}
        self.favicons = []

    def handle_starttag(self, tag, attrs):
        attributes = dict(attrs)
        if tag == "input" and attributes.get("name") == "__palette":
            self.palettes[attributes["data-md-color-scheme"]] = attributes
        if tag == "link" and attributes.get("rel") == "icon":
            self.favicons.append(attributes["href"])
        for name, value in attrs:
            if (tag == "a" and name == "href") or name == "src" or (
                tag == "link" and name == "href"
            ):
                self.paths.append(value)


# Relative assets and links must resolve inside the site when opened through file://.
for html in site.rglob("*.html"):
    parser = Links()
    parser.feed(html.read_text())
    assert len(parser.favicons) == 1, html
    assert (html.parent / parser.favicons[0]).resolve() == (
        site / "assets/nixos-logo.png"
    ).resolve(), html
    assert set(parser.palettes) == {"default", "slate"}, html
    for scheme, preference, action in (
        ("default", "light", "dark"),
        ("slate", "dark", "light"),
    ):
        palette = parser.palettes[scheme]
        assert palette["data-md-color-media"] == f"(prefers-color-scheme: {preference})", html
        assert palette["aria-label"] == f"Switch to {action} mode", html
    for target in parser.paths:
        url = urlsplit(target)
        if url.scheme or url.netloc or not url.path:
            continue
        assert not url.path.startswith("/"), (html, target)
        resolved = (html.parent / unquote(url.path)).resolve()
        assert resolved.is_relative_to(site.resolve()), (html, target)
        assert resolved.is_file(), (html, target)

assert (site / "assets/nixos-logo.png").read_bytes() == (
    source / "docs/assets/nixos-logo.png"
).read_bytes()

for page, marker in {
    "index.html": "documented-home documentation",
    "imperative-steps.html": "Alpha setup marker: override.",
    "modules/zeta.html": "documented-home: fixture, 31",
    "modules/nixos-only.html": "Selected NixOS-only documentation marker.",
    "module-reference.html": "The fixture user.",
}.items():
    assert marker in (site / page).read_text(), page

print("Host documentation content and local links passed")
