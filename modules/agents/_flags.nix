# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Claude Code options that consume following arguments, from `claude --help`.
{
  valueFlags = [
    "--agent"
    "--append-system-prompt"
    "--autocompact"
    "--cloud"
    "-d"
    "--debug"
    "--debug-file"
    "--effort"
    "--environment"
    "--fallback-model"
    "--from-pr"
    "--input-format"
    "--json-schema"
    "--max-budget-usd"
    "--model"
    "-n"
    "--name"
    "--output-format"
    "--permission-mode"
    "--permission-prompts"
    "--plugin-dir"
    "--plugin-url"
    "--prompt-suggestions"
    "--remote-control"
    "--remote-control-session-name-prefix"
    "-r"
    "--resume"
    "--session-id"
    "--setting-sources"
    "--settings"
    "--system-prompt"
    "--system-prompt-file"
    "--append-system-prompt-file"
    "--system-prompt-snapshot"
    "--teleport"
    "-w"
    "--worktree"
  ];
  variadicFlags = [
    "--add-dir"
    "--allowedTools"
    "--allowed-tools"
    "--betas"
    "--disallowedTools"
    "--disallowed-tools"
    "--file"
    "--mcp-config"
    "--tools"
  ];
}
