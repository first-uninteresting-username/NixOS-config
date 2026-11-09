# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
"""Generate a cursors_scalable/ tree from an Xcursor theme's cursors/ directory.

GNOME Shell 51 draws the pointer only from cursors_scalable/ (KDE layout: one directory per
cursor with SVG frames and metadata.json) and falls back to its built-in Adwaita cursors
otherwise. Each frame wraps the largest Xcursor image as an embedded PNG, so the theme keeps
its exact pixels and hotspots.
"""

import base64
import json
import os
import struct
import sys
import zlib

IMAGE_TYPE = 0xFFFD0002

# Names GNOME Shell requests that some Xcursor themes lack, mapped to a common equivalent.
EXTRA_ALIASES = {"all-resize": ["fleur", "size_all", "move"]}


def read_frames(path):
    data = open(path, "rb").read()
    if data[:4] != b"Xcur":
        raise ValueError(f"{path}: not an Xcursor file")
    _, _, count = struct.unpack_from("<III", data, 4)
    frames = []
    for index in range(count):
        chunk_type, _, pos = struct.unpack_from("<III", data, 16 + index * 12)
        if chunk_type != IMAGE_TYPE:
            continue
        _, _, nominal, _, width, height, xhot, yhot, delay = struct.unpack_from(
            "<9I", data, pos
        )
        pixels = data[pos + 36 : pos + 36 + width * height * 4]
        frames.append((nominal, width, height, xhot, yhot, delay, pixels))
    largest = max(frame[0] for frame in frames)
    return [frame for frame in frames if frame[0] == largest]


def png(width, height, argb):
    rows = bytearray()
    for y in range(height):
        rows.append(0)
        for (value,) in struct.iter_unpack("<I", argb[y * width * 4 : (y + 1) * width * 4]):
            alpha = value >> 24
            channels = [(value >> shift) & 0xFF for shift in (16, 8, 0)]
            if 0 < alpha < 255:
                # Xcursor stores premultiplied alpha; PNG expects straight alpha.
                channels = [min(255, c * 255 // alpha) for c in channels]
            rows += bytes(channels + [alpha])

    def chunk(kind, body):
        crc = zlib.crc32(kind + body) & 0xFFFFFFFF
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", crc)

    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(bytes(rows), 9))
        + chunk(b"IEND", b"")
    )


def write_cursor(source, target, name):
    os.makedirs(target)
    frames = read_frames(source)
    metadata = []
    for index, (nominal, width, height, xhot, yhot, delay, pixels) in enumerate(frames, 1):
        filename = f"{name}.svg" if len(frames) == 1 else f"{name}-{index:02d}.svg"
        encoded = base64.b64encode(png(width, height, pixels)).decode()
        with open(os.path.join(target, filename), "w") as handle:
            handle.write(
                f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
                f'viewBox="0 0 {width} {height}"><image width="{width}" height="{height}" '
                f'href="data:image/png;base64,{encoded}"/></svg>\n'
            )
        entry = {"filename": filename, "hotspot_x": xhot, "hotspot_y": yhot}
        if len(frames) > 1:
            entry["delay"] = delay
        entry["nominal_size"] = nominal
        metadata.append(entry)
    with open(os.path.join(target, "metadata.json"), "w") as handle:
        json.dump(metadata, handle, indent=4)


def convert(theme):
    cursors = os.path.join(theme, "cursors")
    scalable = os.path.join(theme, "cursors_scalable")
    os.makedirs(scalable, exist_ok=True)
    names = sorted(os.listdir(cursors))
    for name in names:
        source = os.path.join(cursors, name)
        target = os.path.join(scalable, name)
        if os.path.islink(source):
            link = os.readlink(source)
            if "/" not in link and os.path.exists(source):
                os.symlink(link, target)
                continue
        write_cursor(os.path.realpath(source), target, name)
    for alias, candidates in EXTRA_ALIASES.items():
        if alias in names:
            continue
        for candidate in candidates:
            if candidate in names:
                os.symlink(candidate, os.path.join(scalable, alias))
                break


if __name__ == "__main__":
    for theme_dir in sys.argv[1:]:
        convert(theme_dir)
