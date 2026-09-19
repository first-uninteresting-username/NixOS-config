# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
_: {
  flake = {
    nixosModules.git = {
      pkgs,
      lib,
      config,
      ...
    }: {
      preservation.preserveAt = lib.mkIf config.custom.preservation.enable {
        "/persist" = {
          users.${config.custom.user.name} = {
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

      sops.secrets = {
        "github_pat" = {
          owner = config.custom.user.name;
        };
      };
      home-manager.users.${config.custom.user.name} = {
        pkgs,
        osConfig,
        config,
        ...
      }: {
        home.packages = with pkgs; [onefetch meld];
        programs = {
          git = {
            enable = true;
            settings = {
              user = {
                name = "first-uninteresting-username";
                email = "janekmusin@proton.me";
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
          zsh.initContent = lib.mkIf config.programs.zsh.enable ''
            export GH_TOKEN="$(cat ${osConfig.sops.secrets.github_pat.path})"
          '';
          nushell.extraEnv = lib.mkIf config.programs.nushell.enable ''
            $env.GH_TOKEN = (open ${osConfig.sops.secrets.github_pat.path} | str trim)
          '';
        };
      };
    };

    nixosModules.secretless-git = {
      pkgs,
      lib,
      config,
      ...
    }: {
      preservation.preserveAt = lib.mkIf config.custom.preservation.enable {
        "/persist" = {
          users.${config.custom.user.name} = {
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

      home-manager.users.${config.custom.user.name} = {pkgs, ...}: {
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
  };
}
