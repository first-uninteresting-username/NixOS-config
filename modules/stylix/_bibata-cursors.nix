# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
# Bibata with the cursors_scalable/ tree GNOME Shell 51 requires; without it the shell falls
# back to its built-in Adwaita pointer.
{
  bibata-cursors,
  python3,
  runCommand,
}:
runCommand "${bibata-cursors.name}-scalable" {
  nativeBuildInputs = [python3];
  inherit (bibata-cursors) meta;
} ''
  for source in ${bibata-cursors}/share/icons/*; do
    theme=$out/share/icons/$(basename "$source")
    mkdir -p "$theme"
    ln -s "$source/cursors" "$theme/cursors"
    cp "$source/index.theme" "$theme/index.theme"
    # Upstream cursor.theme inherits itself, which breaks fallback lookup.
    sed 's/^Inherits=.*/Inherits=Adwaita/' "$source/cursor.theme" > "$theme/cursor.theme"
  done
  python3 ${./_xcursor-to-scalable.py} $out/share/icons/*
''
