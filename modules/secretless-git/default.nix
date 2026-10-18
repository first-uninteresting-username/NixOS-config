# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "secretless-git";
  ids = ["secretless-git"];
  module = _: {
    nixos = {
      pkgs,
      lib,
      userName,
      preservationEnable,
      ...
    }: {
      preservation.preserveAt = lib.mkIf preservationEnable {
        "/persist" = {
          users.${userName} = {
            directories = [
              ".config/git"
              ".config/gh"
            ];
          };
        };
      };

      programs.git.enable = lib.mkForce false;

      environment.systemPackages = with pkgs; [
        git
        gh
      ];
    };
    home = {pkgs, ...}: {
      home.packages = with pkgs; [onefetch meld];
      programs = {
        git = {
          enable = true;
          settings = {
            user = {
              name = "local";
              email = "local@local.local";
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
      };
    };
  };
}
