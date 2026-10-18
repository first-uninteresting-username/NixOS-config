# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "shell-secret-programs";
  ids = ["shell-secret-programs"];
  module = {hackApiKeyPath ? "/run/secrets/HACK_CLUB_AI_API_KEY"}: {
    nixos = {
      lib,
      config,
      userName,
      shell,
      ...
    }: {
      config = lib.mkIf ((config ? sops) && shell.enable) {
        sops.secrets."HACK_CLUB_AI_API_KEY" = {
          path = hackApiKeyPath;
          owner = userName;
        };
      };
    };
    home = {
      shell,
      inputs,
      lib,
      ...
    }: {
      imports = [inputs.hack.homeManagerModules.default];
      config = lib.mkIf shell.enable {
        programs.hack = {
          enable = true;
          settings = {
            base_url = "https://ai.hackclub.com/proxy/v1";
            model = "deepseek/deepseek-v4-flash-0731";
            api_key_path = hackApiKeyPath;
          };
        };
      };
    };
  };
}
