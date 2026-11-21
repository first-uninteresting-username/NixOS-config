# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Starts interactive sessions in ~/Agents unless the current directory or one of its parents
# contains AGENTS.md. Other arguments are not inspected, except that `stayFlags` (such as
# Claude Code's --print) keep the current directory. The wrapper-only --here flag keeps the
# current directory and is removed from the arguments.
{
  lib,
  stayFlags ? [],
}: let
  stayCase = lib.optionalString (stayFlags != []) ''
    ${lib.concatMapStringsSep "|" lib.escapeShellArg stayFlags})
      agentsFallbackApplies=0
      set -- "$@" "$agentsFallbackArg"
      ;;
  '';
in ''
  agentsFallbackApplies=1
  agentsFallbackCount=$#
  while [ "$agentsFallbackCount" -gt 0 ]; do
    agentsFallbackArg=$1
    shift
    case $agentsFallbackArg in
      --here) agentsFallbackApplies=0 ;;
      ${stayCase}      *) set -- "$@" "$agentsFallbackArg" ;;
    esac
    agentsFallbackCount=$((agentsFallbackCount - 1))
  done
  if [ ! -t 0 ] || [ ! -t 1 ] || [ -e /AGENTS.md ]; then
    agentsFallbackApplies=0
  fi
  agentsFallbackDir=$PWD
  while [ "$agentsFallbackApplies" = 1 ] && [ -n "$agentsFallbackDir" ]; do
    if [ -e "$agentsFallbackDir/AGENTS.md" ]; then
      agentsFallbackApplies=0
    fi
    agentsFallbackDir=''${agentsFallbackDir%/*}
  done
  if [ "$agentsFallbackApplies" = 1 ]; then
    mkdir -p "$HOME/Agents"
    cd "$HOME/Agents"
  fi
''
