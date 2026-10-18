# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{lib, ...}: {
  shell = {
    description = "Settings for shell.";
    default = {};
    type = lib.types.submodule (_: {
      options = {
        enable = lib.mkEnableOption "shell config";
        name = lib.mkOption {
          type = lib.types.nullOr (lib.types.enum ["nushell" "zsh"]);
          default = null;
          example = "nushell";
          description = "Name of the shell to be enabled and configured";
        };
      };
    });
  };
}
