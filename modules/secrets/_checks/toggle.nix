# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  self,
  inputs,
  lib,
  pkgs,
  system,
}: let
  moduleLib = import ../../../lib/modules {inherit self inputs lib;};
  registry = moduleLib.mkRegistry {
    commonArgs = self.lib.modules.commonArgs;
    modules =
      map (name: import ../../${name}/default.nix {inherit (moduleLib) mkModule;}) [
        "secrets"
        "preservation"
        "git"
        "ssh"
        "networking-desktop"
        "desktop-password"
        "IDE"
        "hack"
        "home-manager"
        "xdg"
        "user"
      ]
      ++ [
        (moduleLib.mkModule {
          name = "fixture";
          module = _: {
            nixos = _: {
              system.stateVersion = "26.11";
              boot.loader.grub.enable = false;
              fileSystems."/" = {
                device = "none";
                fsType = "tmpfs";
              };
            };
            home = _: {
              programs.zsh.enable = true;
              programs.nushell.enable = true;
            };
          };
        })
      ];
  };
  ids = [
    "preservation"
    "git"
    "ssh"
    "networking-desktop"
    "desktop-password"
    "IDE"
    "hack"
    "home-manager"
    "xdg"
    "user"
  ];
  fixture = role: enabled: withSecrets:
    registry.mkHost {
      name = "secrets-fixture";
      inherit role system;
      ids = ids ++ lib.optional withSecrets "secrets";
      args =
        {
          userName = "fixture";
          secretsEnable = enabled;
        }
        // lib.optionalAttrs (role == "nixos") {
          userEnable = true;
          preservationEnable = false;
        }
        // lib.optionalAttrs (role == "nixos" && !enabled) {
          userHashedPassword = "!";
        };
    };
  # Omit sops entirely to catch accidental option and credential-file dependencies.
  disabled = fixture "nixos" false false;
  enabled = fixture "nixos" true true;
  selectedDisabled = fixture "nixos" false true;
  standalone = fixture "home" false false;
  disabledHome = disabled.config.home-manager.users.fixture;
  enabledHome = enabled.config.home-manager.users.fixture;
  noTokenReads = home:
    !(lib.hasInfix "/run/secrets/" home.programs.zsh.initContent)
    && !(lib.hasInfix "/run/secrets/" home.programs.nushell.extraEnv);
in
  assert builtins.isString disabled.config.system.build.toplevel.drvPath;
  assert builtins.isString enabled.config.system.build.toplevel.drvPath;
  assert builtins.isString selectedDisabled.config.system.build.toplevel.drvPath;
  assert builtins.isString standalone.activationPackage.drvPath;
  assert !(disabled.config ? sops);
  assert selectedDisabled.config.sops.secrets == {};
  assert !(selectedDisabled.config.systemd.services ? sops-install-secrets);
  assert !(disabled.config.systemd.services ? nm-wifi-secret);
  assert noTokenReads disabledHome;
  assert noTokenReads standalone.config;
  assert lib.hasInfix "/run/secrets/github_pat" enabledHome.programs.zsh.initContent;
  assert lib.hasInfix "/run/secrets/github_pat" enabledHome.programs.nushell.extraEnv;
    pkgs.runCommand "secrets-toggle" {} ''
      touch "$out"
    ''
