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
  }: let
    # gh reads the token file itself, so services and desktop sessions that never start a
    # shell are authenticated too. An explicit GH_TOKEN or GITHUB_TOKEN still takes precedence.
    mkGh = pkgs:
      if !secretsEnable
      then pkgs.gh
      else
        pkgs.symlinkJoin {
          name = "gh-${pkgs.gh.version}";
          inherit (pkgs.gh) version meta;
          paths = [pkgs.gh];
          nativeBuildInputs = [pkgs.makeWrapper];
          postBuild = ''
            wrapProgram "$out/bin/gh" --run '
              if [ -z "''${GH_TOKEN-}''${GITHUB_TOKEN-}" ] && [ -r ${githubTokenPath} ]; then
                export GH_TOKEN="$(< ${githubTokenPath})"
              fi'
          '';
          passthru.tokenPath = githubTokenPath;
        };
  in {
    nixos = {
      pkgs,
      lib,
      userName,
      ...
    }:
      {
        programs.git.enable = lib.mkForce false;

        environment.systemPackages = [pkgs.git (mkGh pkgs)];
      }
      // lib.optionalAttrs secretsEnable {
        sops.secrets = {
          "github_pat" = {
            path = githubTokenPath;
            owner = userName;
          };
        };
      };
    home = {pkgs, ...}: {
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
          package = mkGh pkgs;
          settings = {
            git_protocol = "https";
            prompt = "enabled";
          };
        };
      };
    };
  };
}
