# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "preservation";
  ids = ["preservation"];
  docs = ''
    Selected modules declare the system and home state retained under `/persist`.
    These declarations take effect only when `preservationEnable` is true.
    System paths and home-relative paths remain separate in the preservation configuration.
  '';
  module = _: {
    nixos = {
      lib,
      config,
      userName,
      preservationEnable,
      inputs,
      ...
    }: {
      imports = [
        inputs.preservation.nixosModules.preservation
      ];

      config = lib.mkIf preservationEnable {
        boot = {
          initrd.systemd.enable = true;
          tmp = {
            useTmpfs = true;
            cleanOnBoot = true;
          };
        };

        systemd = {
          services.systemd-machine-id-commit = {
            unitConfig.ConditionPathIsMountPoint = ["" "/persist/etc/machine-id"];
            serviceConfig.ExecStart = ["" "systemd-machine-id-setup --commit --root /persist"];
          };
          tmpfiles.rules = [
            "d /persist/home/${userName} 0700 ${userName} users -"
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
                createLinkTarget = true;
                configureParent = true;
              }
            ];

            users.${userName} = {
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
      };
    };
  };
  checks = {
    self,
    inputs,
    lib,
    pkgs,
    system,
    ...
  }:
    lib.optionalAttrs (system == "x86_64-linux") {
      persistence = {
        derivation = (import ./_checks/persistence.nix {inherit self inputs lib pkgs;}).check;
        extraFiles = ["modules/ssh/default.nix" "modules/bootloader/default.nix"];
      };
    };
}
