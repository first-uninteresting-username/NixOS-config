# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "stylix";
  ids = ["stylix"];
  packages = {pkgs, ...}: {
    bibata-cursors = pkgs.callPackage ./_bibata-cursors.nix {};
  };
  checks = {
    pkgs,
    packages,
    ...
  }: {
    # GNOME Shell 51 falls back to Adwaita for any cursor name missing from cursors_scalable/.
    bibata-cursors =
      pkgs.runCommand "stylix-bibata-cursors-check" {
        nativeBuildInputs = [pkgs.python3];
      } ''
        python3 ${./_check-scalable-cursors.py} \
          ${packages.bibata-cursors}/share/icons/Bibata-Modern-Ice
        touch $out
      '';
  };
  module = _: {
    nixos = {
      lib,
      pkgs,
      config,
      theme,
      inputs,
      packages,
      ...
    }: {
      imports = [
        inputs.stylix.nixosModules.stylix
      ];

      config = lib.mkIf theme.enable {
        nix.settings = {
          extra-substituters = ["https://nix-community.cachix.org"];
          extra-trusted-public-keys = ["nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="];
        };

        programs.dconf.enable = true;

        stylix =
          (import ./_style.nix {inherit config lib pkgs inputs theme packages;})
          // {
            enable = true;
            autoEnable = false;
          };
      };
    };
    home = {
      lib,
      theme,
      inputs,
      config,
      pkgs,
      packages,
      osConfig ? null,
      ...
    }: {
      imports = lib.optional (osConfig == null) inputs.stylix.homeModules.stylix;
      config = lib.mkIf theme.enable {
        qt = {
          enable = true;
          style.name = lib.mkForce "breeze";
        };
        gtk.enable = true;

        stylix =
          (lib.optionalAttrs (osConfig == null) (import ./_style.nix {inherit config lib pkgs inputs theme packages;}))
          // {
            autoEnable = true;
            enable = true;
          };
      };
    };
  };
}
