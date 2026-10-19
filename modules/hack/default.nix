# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "hack";
  ids = ["hack"];
  module = {hackApiKeyPath ? "/run/secrets/HACK_CLUB_AI_API_KEY"}: {
    nixos = {
      lib,
      secretsEnable,
      userName,
      ...
    }: {
      config = lib.optionalAttrs secretsEnable {
        sops.secrets."HACK_CLUB_AI_API_KEY" = {
          path = hackApiKeyPath;
          owner = userName;
        };
      };
    };
    home = {
      inputs,
      lib,
      secretsEnable,
      ...
    }: {
      imports = [inputs.hack.homeManagerModules.default];
      config = {
        programs.hack = {
          enable = true;
          settings =
            {
              base_url = "https://ai.hackclub.com/proxy/v1";
              model = "deepseek/deepseek-v4.1-flash-1017";
            }
            // lib.optionalAttrs secretsEnable {
              api_key_path = hackApiKeyPath;
            };
        };
      };
    };
  };
  packages = {
    inputs,
    system,
    ...
  }: {default = inputs.hack.packages.${system}.default;};
}
