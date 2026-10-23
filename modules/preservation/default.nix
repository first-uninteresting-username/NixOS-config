# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "preservation";
  ids = ["preservation"];
  docs = ''
    Selected modules declare system and home state with their `state` field.
    With `preservationEnable` true, this module keeps that state under `/persist`:
    system paths at their absolute location and home paths under the user's home.
    The host documentation's State page lists every declared path.
  '';
  state = {
    nixos = {
      directories = [
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
    };
    home.directories = [
      ".cache/mesa_shader_cache"
      "persist"
      ".cache/fontconfig"
    ];
  };
  module = _: {
    nixos = {
      lib,
      config,
      userName,
      preservationEnable,
      state,
      inputs,
      ...
    }: let
      entries = scope: kind: lib.concatMap (declared: declared.${kind}) (builtins.attrValues state.${scope});
      # A separate /var/lib filesystem already retains its contents.
      outsideVarLib = entry: let
        path =
          if builtins.isString entry
          then entry
          else entry.directory or entry.file;
      in
        !(config.fileSystems ? "/var/lib" && lib.hasPrefix "/var/lib" path);
    in {
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
            directories = lib.filter outsideVarLib (entries "nixos" "directories");
            files = lib.filter outsideVarLib (entries "nixos" "files");
            users.${userName} = {
              directories = entries "home" "directories";
              files = entries "home" "files";
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
      persistence = (import ./_checks/persistence.nix {inherit self inputs lib pkgs;}).check;
    };
}
