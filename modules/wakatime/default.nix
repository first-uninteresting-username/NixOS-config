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
    needs wakatime-cli 2.27.1 or later, so the module overlays a newer release than nixpkgs and
    exports it as the `wakatime` package. `nix run .#update-packages` keeps that release current.
    Evaluation fails once nixpkgs ships 2.27.1 or later; then remove the overlay and export.
  '';
  # Exported so CI builds the overlaid release (and runs its tests) whenever this module changes.
  packages = {pkgs, ...}: {default = import ./_package.nix pkgs;};
  checks = {
    pkgs,
    packages,
    ...
  }: {
    # `exclude_ai` is silently ignored before 2.27.1.
    exclude-ai-support = pkgs.runCommand "wakatime-exclude-ai-support" {} ''
      export HOME=$TMPDIR
      version=$(${pkgs.lib.getExe packages.default} --version)
      version=''${version#v}
      echo "wakatime-cli $version"
      [ "$(printf '%s\n' 2.27.1 "$version" | sort -V | head -n1)" = 2.27.1 ]
      touch "$out"
    '';
  };
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
        nixpkgs.overlays = [(_: prev: {wakatime-cli = import ./_package.nix prev;})];
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
