# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Flag values such as `--model opus` once disabled the ~/Agents fallback.
{
  pkgs,
  fallback,
}: let
  wrapper = pkgs.writeShellScript "agents-fallback-probe" ''
    ${fallback}
    pwd
  '';
in
  pkgs.runCommand "agents-claude-fallback" {nativeBuildInputs = [pkgs.util-linux];} ''
    export HOME=$TMPDIR/home
    mkdir -p "$HOME" "$TMPDIR/start"
    cd "$TMPDIR/start"
    expect() {
      want=$1
      shift
      got=$(script -qec "${wrapper} $*" /dev/null | tr -d '\r')
      if [ "$got" != "$want" ]; then
        echo "claude $*: started in $got, expected $want" >&2
        exit 1
      fi
    }
    expect "$HOME/Agents"
    expect "$HOME/Agents" --continue
    expect "$HOME/Agents" --model opus
    expect "$HOME/Agents" --resume 1234 --effort high
    expect "$HOME/Agents" --add-dir a b
    expect "$TMPDIR/start" fix the bug
    expect "$TMPDIR/start" --model opus fix
    expect "$HOME/Agents" --resume
    expect "$TMPDIR/start" --here --model opus
    expect "$TMPDIR/start" -p hi
    touch $out
  ''
