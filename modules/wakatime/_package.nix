# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
# Nixpkgs' wakatime-cli with the AI session patch.
# Takes the package set to build from: the overlay passes `prev`, the export passes `pkgs`.
pkgs: let
  # `exclude_ai` first shipped in this release; older releases silently ignore it.
  minimum = "2.27.1";
in
  assert pkgs.lib.assertMsg (pkgs.lib.versionAtLeast pkgs.wakatime-cli.version minimum)
  "wakatime: Nixpkgs ships wakatime-cli ${pkgs.wakatime-cli.version}, but exclude_ai needs ${minimum}.";
    pkgs.wakatime-cli.overrideAttrs (previous: {
      # Upstream applies `exclude_ai` only to file heartbeats, so per-prompt session heartbeats
      # ("Claude <id>") still log AI time for any project. Match their working directory too.
      patches = (previous.patches or []) ++ [./_exclude-ai-session-project-path.diff];
    })
