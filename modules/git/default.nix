# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "git";
  ids = ["git"];
  state = {
    home.directories = [
      ".config/git"
      ".config/gh"
    ];
  };
  module = {
    secretsEnable,
    githubTokenPath ? "/run/secrets/github_pat",
  }: {
    nixos = {
      pkgs,
      lib,
      userName,
      ...
    }:
      {
        programs.git.enable = lib.mkForce false;

        environment.systemPackages = with pkgs; [
          git
          gh
        ];
      }
      // lib.optionalAttrs secretsEnable {
        sops.secrets = {
          "github_pat" = {
            path = githubTokenPath;
            owner = userName;
          };
        };
      };
    home = {
      pkgs,
      config,
      lib,
      ...
    }: {
      home.packages = with pkgs; [onefetch meld];
      programs = {
        git = {
          enable = true;
          settings = {
            user = {
              name =
                if secretsEnable
                then "first-uninteresting-username"
                else "local";
              email =
                if secretsEnable
                then "janekmusin@proton.me"
                else "local@local.local";
            };
            push = {
              autoSetupRemote = true;
            };
            init.defaultBranch = "main";
            pull.rebase = true;
            rerere.enabled = true;
            merge.tool = "meld";
            mergetool.keepBackup = false;
            mergetool.trustExitCode = true;
          };
        };
        gh = {
          enable = true;
          settings = {
            git_protocol = "https";
            prompt = "enabled";
          };
        };
        fish.shellInit = lib.mkIf (secretsEnable && config.programs.fish.enable) ''
          set -gx GH_TOKEN (string trim < ${githubTokenPath})
        '';
      };
    };
  };
}
