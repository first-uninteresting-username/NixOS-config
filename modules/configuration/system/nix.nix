# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{inputs, ...}: {
  flake = {
    nixosModules.nix = {
      lib,
      config,
      ...
    }: {
      preservation.preserveAt = lib.mkIf config.custom.preservation.enable {
        "/persist" = {
          users.${config.custom.user.name} = {
            directories = [
              ".cache/nix"
            ];
          };
        };
      };
      nix = {
        registry = {
          nixpkgs.flake = inputs.nixpkgs;
          # Allows me to use shorthand 'config' instead of 'github:first-uninteresting-username/NixOS-config'
          config.to = {
            type = "github";
            owner = "first-uninteresting-username";
            repo = "NixOS-config";
            ref = "main";
          };
        };
        settings = {
          experimental-features = [
            "nix-command"
            "flakes"
          ];

          flake-registry = "${inputs.flake-registry}/flake-registry.json";

          substituters = [
            "https://cache.nixos.org?priority=40"
            "https://nix-community.cachix.org"
            "https://matrix.cachix.org?priority=42"
            "https://devenv.cachix.org"
            # The goat of caches
            "https://cache.numtide.com?priority=41"
            "https://attic.xuyh0120.win/lantian"
          ];

          trusted-public-keys = [
            "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            "matrix.cachix.org-1:uZWavEIj0/oIRHPjh+OG586y4nXBlyI0xkYfZBfDx7w="
            "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
            "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
            "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
          ];

          max-jobs = "auto";
          cores = 0;
          trusted-users = [
            "root"
            "@wheel"
          ];
          warn-dirty = false;
          keep-derivations = true;
        };
        channel.enable = false;
      };

      nixpkgs.config = {
        allowUnfree = true;
        allowBroken = false;
      };

      documentation.nixos.enable = false;

      environment.defaultPackages = [];

      programs.nix-ld = {
        enable = true;
        libraries = [];
      };
    };
  };
}
