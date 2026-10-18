# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "iso";
  ids = ["iso"];
  module = _: {
    nixos = {
      pkgs,
      userName,
      self,
      ...
    }: {
      boot.zfs.forceImportRoot = false;

      environment.defaultPackages = with pkgs; [
        nano
        netcat
        disko
        nixos-anywhere
        micro
      ];

      isoImage.contents = [
        {
          source = self.outPath;
          target = "/flake-source";
        }
      ];

      systemd.tmpfiles.rules = [
        "C /etc/nixos - - - - /flake-source"
        "Z /etc/nixos 0777 ${userName} ${userName} -"
      ];
    };
    home = {
      homeStateVersion,
      lib,
      ...
    }: {
      home.stateVersion = lib.mkForce homeStateVersion;
    };
  };
  checks = {
    self,
    lib,
    pkgs,
    system,
    ...
  }:
    lib.optionalAttrs (system == "x86_64-linux") (let
      fixtures = (import ./_checks/smoke.nix {inherit self pkgs;}).checks;
    in {
      john = {
        derivation = fixtures.iso-john;
        extraFiles = ["hosts/john.nix" "modules/host-john/default.nix"];
      };
      wall-e = {
        derivation = fixtures.iso-wall-e;
        extraFiles = ["hosts/wall-e.nix" "modules/host-wall-e/default.nix"];
      };
    });
}
