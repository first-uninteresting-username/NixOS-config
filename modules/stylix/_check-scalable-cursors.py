# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
"""Fail unless every cursor GNOME Shell 51 requests resolves in a theme's cursors_scalable/."""

import json
import os
import sys

# CSS cursor names GNOME Shell 51 ships built-in fallbacks for.
REQUIRED = """
    alias all-resize all-scroll cell col-resize context-menu copy crosshair default e-resize
    ew-resize grab grabbing help n-resize ne-resize nesw-resize no-drop not-allowed
    ns-resize nw-resize nwse-resize pointer progress row-resize s-resize se-resize sw-resize
    text vertical-text w-resize wait zoom-in zoom-out
""".split()

scalable = os.path.join(sys.argv[1], "cursors_scalable")
errors = []
for name in REQUIRED:
    directory = os.path.join(scalable, name)
    try:
        frames = json.load(open(os.path.join(directory, "metadata.json")))
    except (OSError, ValueError) as error:
        errors.append(f"{name}: {error}")
        continue
    for frame in frames:
        if not os.path.isfile(os.path.join(directory, frame["filename"])):
            errors.append(f"{name}: missing {frame['filename']}")
        if not {"hotspot_x", "hotspot_y", "nominal_size"} <= frame.keys():
            errors.append(f"{name}: incomplete metadata")
if errors:
    sys.exit("\n".join(errors))
