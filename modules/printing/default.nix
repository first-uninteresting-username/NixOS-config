# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "printing";
  ids = ["printing"];
  module = _: {
    nixos = {
      lib,
      preservationEnable,
      ...
    }: {
      preservation.preserveAt = lib.mkIf preservationEnable {
        "/persist" = {
          directories = [
            "/var/lib/cups"
          ];
        };
      };

      users.groups.netdev = {};
      services.avahi = {
        enable = true;
        nssmdns4 = true;
        openFirewall = true;
      };

      services.printing = {
        enable = true;
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
      discovery = {
        derivation = (import ./_checks/discovery.nix {inherit self inputs lib pkgs;}).check;
        extraFiles = ["modules/networking-desktop/default.nix"];
      };
    };
}
