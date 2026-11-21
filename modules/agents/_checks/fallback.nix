# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Flag values such as `--model opus` once kept sessions out of ~/Agents.
{
  pkgs,
  fallback,
}: let
  wrapper = pkgs.writeShellScript "agents-fallback-probe" ''
    ${fallback}
    echo "$PWD $*"
  '';
in
  pkgs.runCommand "agents-claude-fallback" {nativeBuildInputs = [pkgs.util-linux];} ''
    export HOME=$TMPDIR/home
    mkdir -p "$HOME" "$TMPDIR/start" "$TMPDIR/project/sub"
    touch "$TMPDIR/project/AGENTS.md"
    cd "$TMPDIR/start"
    expect() {
      want=$1
      shift
      got=$(script -qec "${wrapper} $*" /dev/null | tr -d '\r')
      if [ "$got" != "$want" ]; then
        echo "claude $*: got '$got', expected '$want'" >&2
        exit 1
      fi
    }
    agents=$HOME/Agents
    expect "$agents "
    expect "$agents --continue" --continue
    expect "$agents --model opus" --model opus
    expect "$agents --resume 1234 --effort high" --resume 1234 --effort high
    expect "$agents fix the bug" fix the bug
    expect "$agents mcp list" mcp list
    expect "$TMPDIR/start --model opus" --here --model opus
    expect "$TMPDIR/start -p hi" -p hi
    expect "$TMPDIR/start --model opus --print hi" --model opus --print hi
    got=$(${wrapper} --model opus)
    [ "$got" = "$TMPDIR/start --model opus" ] || { echo "non-tty: got '$got'" >&2; exit 1; }
    cd "$TMPDIR/project/sub"
    expect "$TMPDIR/project/sub --model opus" --model opus
    touch $out
  ''
