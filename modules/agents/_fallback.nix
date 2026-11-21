# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Starts interactive sessions in ~/Agents unless the current directory or one of its parents
# contains AGENTS.md. Invocations with subcommands, prompts, paths, or print/help/version flags
# run unchanged. Arguments after a flag in `valueFlags` (one argument) or `variadicFlags` (every
# following non-flag argument) are flag values, not prompts. The wrapper-only flags are removed
# from the arguments: --here keeps the current directory and --agents always switches to
# ~/Agents.
{
  lib,
  valueFlags ? [],
  variadicFlags ? [],
}: let
  flagCase = flags: skip:
    lib.optionalString (flags != []) ''
      ${lib.concatMapStringsSep "|" lib.escapeShellArg flags}) agentsFallbackSkip=${skip} ;;
    '';
in ''
  agentsFallbackApplies=1
  agentsFallbackForce=0
  agentsFallbackCount=$#
  while [ "$agentsFallbackCount" -gt 0 ]; do
    agentsFallbackArg=$1
    shift
    if [ "$agentsFallbackArg" = --here ]; then
      agentsFallbackApplies=0
      agentsFallbackForce=0
    elif [ "$agentsFallbackArg" = --agents ]; then
      agentsFallbackApplies=1
      agentsFallbackForce=1
    else
      set -- "$@" "$agentsFallbackArg"
    fi
    agentsFallbackCount=$((agentsFallbackCount - 1))
  done
  if [ "$agentsFallbackForce" = 1 ]; then
    mkdir -p "$HOME/Agents"
    cd "$HOME/Agents"
  elif [ -t 0 ] && [ -t 1 ]; then
    agentsFallbackSkip=0
    for agentsFallbackArg in "$@"; do
      case $agentsFallbackArg in
        -p|--print|-h|--help|-v|--version) agentsFallbackApplies=0 ;;
        ${flagCase valueFlags "1"}${flagCase variadicFlags "2"}-*) agentsFallbackSkip=0 ;;
        *)
          if [ "$agentsFallbackSkip" = 0 ]; then
            agentsFallbackApplies=0
          elif [ "$agentsFallbackSkip" = 1 ]; then
            agentsFallbackSkip=0
          fi
          ;;
      esac
    done
    agentsFallbackDir=$PWD
    while [ "$agentsFallbackApplies" = 1 ] && [ -n "$agentsFallbackDir" ]; do
      if [ -e "$agentsFallbackDir/AGENTS.md" ]; then
        agentsFallbackApplies=0
      fi
      agentsFallbackDir=''${agentsFallbackDir%/*}
    done
    if [ "$agentsFallbackApplies" = 1 ] && [ ! -e /AGENTS.md ]; then
      mkdir -p "$HOME/Agents"
      cd "$HOME/Agents"
    fi
  fi
''
