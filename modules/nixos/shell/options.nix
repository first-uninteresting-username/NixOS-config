# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{self, ...}: {
  flake = {
    nixosModules.shell = {lib, ...}: {
      imports = [
        self.nixosModules.nushell
        self.nixosModules.shell-programs
        self.nixosModules.zsh
      ];
      options.custom.shell = {
        enable = lib.mkEnableOption "shell config";
        name = lib.mkOption {
          type = lib.types.nullOr (lib.types.enum ["nushell" "zsh"]);
          default = null;
          example = "nushell";
          description = "Name of the shell to be enabled and configured";
        };
      };
    };
  };
}
