# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "wakatime";
  ids = ["IDE"];
  docs = ''
    Reports coding time to Hackatime for every editor selected with the `IDE` ID. It installs
    `wakatime-cli`; the Zed, Kate, and Claude Code plugins use the one on PATH. With secrets
    enabled, sops writes `~/.wakatime.cfg` with the Hackatime API URL and key.
    Run `canistopcoding` to print today's total.

    AI coding detection (`sync_ai_disabled = false`) is on only inside `~/Agents`: `exclude_ai`
    skips AI heartbeats for every other file path, while human activity is still logged
    everywhere. AI session heartbeats without a file path cannot be excluded. `exclude_ai`
    needs wakatime-cli 2.27.1 or later, so the module overlays a newer release than nixpkgs.
  '';
  state = {
    home.directories = [".wakatime"];
  };
  module = {secretsEnable}: {
    nixos = {
      lib,
      config,
      userName,
      ...
    }: let
      home = config.users.users.${userName}.home;
    in
      {
        # nixpkgs ships 2.26.15, which ignores `exclude_ai`; 2.28.0 needs Go 1.27.3.
        nixpkgs.overlays = [
          (_: prev: {
            wakatime-cli =
              (prev.wakatime-cli.override {buildGoModule = prev.buildGo127Module;}).overrideAttrs
              (finalAttrs: _: {
                version = "2.28.0";
                src = prev.fetchFromGitHub {
                  owner = "wakatime";
                  repo = "wakatime-cli";
                  tag = "v${finalAttrs.version}";
                  hash = "sha256-GWZLCL+u4tQQ0k5cQaYOPc/pZbjfrP73/SEooNusrRc=";
                };
                vendorHash = "sha256-ElSlITp0zD77nn2afNeAn/Dn17je+hyKD+mCLevBZGE=";
              });
          })
        ];
      }
      // lib.optionalAttrs secretsEnable {
        sops = {
          secrets."wakatime_api_key" = {};
          templates.".wakatime.cfg" = {
            # wakatime-cli falls back to regexp2 for the lookahead.
            content = ''
              [settings]
              api_url = https://hackatime.hackclub.com/api/hackatime/v1
              api_key = ${config.sops.placeholder.wakatime_api_key}
              heartbeat_rate_limit_seconds = 1
              sync_ai_disabled = false
              exclude_ai = ^(?!${lib.escapeRegex "${home}/Agents"}(/|$))
            '';
            path = "${home}/.wakatime.cfg";
            owner = userName;
            group = userName;
            mode = "0444";
          };
        };
      };
    home = {pkgs, ...}: {
      home = {
        packages = [pkgs.wakatime-cli];
        shellAliases.canistopcoding = "wakatime-cli --today";
      };
    };
  };
}
