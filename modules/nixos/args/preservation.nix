# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{inputs, ...}: {
  flake = {
    nixosModules.preservation = {
      lib,
      config,
      ...
    }: let
      cfg = config.custom.preservation;
    in {
      imports = [
        inputs.preservation.nixosModules.preservation
      ];

      options.custom.preservation = {
        enable = lib.mkEnableOption "preservation module. It may work unpredictably if you don't have /persist partition.";
      };

      config = lib.mkIf cfg.enable {
        boot = {
          initrd.systemd.enable = true;
          tmp = {
            useTmpfs = true;
            cleanOnBoot = true;
          };
        };

        systemd = {
          suppressedSystemUnits = ["systemd-machine-id-commit.service"];
          services.systemd-machine-id-commit = {
            unitConfig.ConditionPathIsMountPoint = ["" "/persist/etc/machine-id"];
            serviceConfig.ExecStart = ["" "systemd-machine-id-setup --commit --root /persist"];
          };
          tmpfiles.rules = [
            "d /persist/home/${config.custom.user.name} 0700 ${config.custom.user.name} users -"
          ];
        };

        preservation = {
          enable = true;
          preserveAt."/persist" = {
            commonMountOptions = ["x-gvfs-hide"];

            directories =
              lib.filter (
                d: let
                  dir =
                    if builtins.isString d
                    then d
                    else d.directory;
                in
                  !(config.fileSystems ? "/var/lib" && lib.hasPrefix "/var/lib" dir)
              ) [
                "/var/lib/nixos"
                "/var/lib/systemd"
                "/var/log"
                "/var/lib/AccountsService"
              ];

            files = [
              "/etc/adjtime"
              {
                file = "/etc/ssh/ssh_host_ed25519_key";
                how = "symlink";
                configureParent = true;
              }
              {
                file = "/etc/ssh/ssh_host_ed25519_key.pub";
                how = "symlink";
                configureParent = true;
              }
              {
                file = "/etc/machine-id";
                inInitrd = true;
                how = "symlink";
                configureParent = true;
              }
            ];

            users.${config.custom.user.name} = {
              directories = [
                ".cache/mesa_shader_cache"
                "persist"
                ".cache/fontconfig"
              ];

              files = [
              ];
            };
          };
        };

        fileSystems = {
          "/" = {
            neededForBoot = true;
          };
          "/nix" = {
            neededForBoot = true;
          };
          "/persist" = {
            neededForBoot = true;
          };
        };
        home-manager.users.${config.custom.user.name} = _: {
          programs = {
            zsh.initContent = ''
              if [[ $PWD == $HOME ]]; then
                  cd ~/persist
              fi
            '';
            nushell.extraConfig = ''
              if $env.PWD == $env.HOME {
                cd ~/persist
              }
            '';
          };
        };
      };
    };
  };
}
