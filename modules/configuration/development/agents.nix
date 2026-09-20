# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{inputs, ...}: {
  flake = {
    nixosModules.agents = {
      lib,
      config,
      pkgs,
      ...
    }: {
      preservation.preserveAt = lib.mkIf config.custom.preservation.enable {
        "/persist" = {
          users.${config.custom.user.name} = {
            directories = [
              ".config/opencode"
              ".local/share/opencode"
              ".config/kilocode"
              ".dsh"
              ".pi"
              ".factory"
            ];
          };
        };
      };

      home-manager.users.${config.custom.user.name} = _: {
        programs = {
          opencode = {
            package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
            enable = true;
          };
        };

        home.packages = [
          inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.kilocode-cli
          inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.ccusage
          inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.dsh
          inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi
          inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.droid
        ];
      };
    };
  };
}
