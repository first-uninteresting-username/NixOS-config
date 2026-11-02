# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
# Editor-independent development tooling. Pair with `ide-proper` (Zed, needs a GPU) or
# `ide-lite` (Kate, CPU rendering).
{mkModule, ...}:
mkModule {
  name = "IDE";
  ids = ["IDE"];
  state = {
    home.directories = [
      ".wakatime"

      ".config/Google"
      ".local/share/Google"
      ".android"
      ".gradle"
      ".cache/Google"
      ".java"

      "Android"
      ".m2"
      ".konan"
    ];
  };
  module = {secretsEnable}: {
    nixos = {
      lib,
      config,
      userName,
      ...
    }:
      lib.optionalAttrs secretsEnable {
        sops = {
          secrets."wakatime_api_key" = {};
          templates.".wakatime.cfg" = {
            content = ''
              [settings]
              api_url = https://hackatime.hackclub.com/api/hackatime/v1
              api_key = ${config.sops.placeholder.wakatime_api_key}
              heartbeat_rate_limit_seconds = 1
              sync_ai_disabled = true
            '';
            path = "${config.users.users.${userName}.home}/.wakatime.cfg";
            owner = userName;
            group = userName;
            mode = "0444";
          };
        };
      };
    home = {pkgs, ...}: {
      programs.micro.enable = true;

      home = {
        packages = with pkgs; [
          nil
          alejandra
          wakatime-cli
          android-tools
          scrcpy
        ];

        sessionVariables.EDITOR = "micro";
        shellAliases.canistopcoding = "wakatime-cli --today";
      };
    };
  };
}
