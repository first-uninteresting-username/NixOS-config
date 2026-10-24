# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  lib,
  self,
  ...
}: {
  perSystem = {
    pkgs,
    self',
    ...
  }: let
    # nix-update edits only this repository; packages from inputs update through flake.lock.
    updatable = lib.filterAttrs (_: package:
      package ? updateScript && lib.hasPrefix "${self}/" (package.meta.position or ""))
    self'.packages;
    names = builtins.attrNames updatable;
    # Run each script as Nixpkgs' maintainers/scripts/update.nix does, with its UPDATE_NIX_* context.
    cases = lib.concatStrings (lib.mapAttrsToList (name: package: ''
        ${lib.escapeShellArg name})
          UPDATE_NIX_NAME=${lib.escapeShellArg package.name} \
            UPDATE_NIX_PNAME=${lib.escapeShellArg (package.pname or package.name)} \
            UPDATE_NIX_OLD_VERSION=${lib.escapeShellArg (package.version or "")} \
            UPDATE_NIX_ATTR_PATH=${lib.escapeShellArg name} \
            ${lib.escapeShellArgs (lib.toList (package.updateScript.command or package.updateScript))}
          ;;
      '')
      updatable);
    program = pkgs.writeShellApplication {
      name = "update-packages";
      runtimeInputs = [pkgs.coreutils pkgs.git];
      text = ''
        update() {
          case "$1" in
            ${cases}
            *)
              echo "update-packages: '$1' has no update script; choose from: ${toString names}" >&2
              return 2
              ;;
          esac
        }

        # Record tracked files through a copy of the index, without creating a commit.
        snapshot() {
          local directory
          directory=$(mktemp -d)
          cp "$(git rev-parse --git-path index)" "$directory/index"
          GIT_INDEX_FILE="$directory/index" git add --update
          GIT_INDEX_FILE="$directory/index" git write-tree
          rm -r "$directory"
        }

        cd "$(git rev-parse --show-toplevel)"
        if [ "$#" -eq 0 ]; then
          set -- ${lib.escapeShellArgs names}
        fi

        failed=()
        for package in "$@"; do
          if [ -n "''${GITHUB_ACTIONS:-}" ]; then echo "::group::Update $package"; fi
          before=$(snapshot)
          if ! update "$package"; then
            # Keep earlier updates, but never leave a partial update of this package behind.
            git restore --source="$before" --worktree -- .
            failed+=("$package")
          fi
          if [ -n "''${GITHUB_ACTIONS:-}" ]; then echo "::endgroup::"; fi
        done

        if [ "''${#failed[@]}" -gt 0 ]; then
          echo "update-packages: failed to update: ''${failed[*]}" >&2
          exit 1
        fi
      '';
    };
  in {
    apps.update-packages = {
      program = lib.getExe program;
      meta.description = "Run the update script of every package declared in this repository";
    };
  };
}
