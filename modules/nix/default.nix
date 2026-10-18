# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "nix";
  ids = ["nix"];
  docs = ''
    The Nix module and GitHub Actions use `https://cache.xinux.uz` for prebuilt CachyOS
    kernels. Both trust the Xinux signing key:

    ```text
    cache.xinux.uz:BXCrtqejFjWzWEB9YuGB7X2MV4ttBur1N8BkwQRdH+0=
    ```

    This replaces the Lantian Attic cache and its signing key after the operator reports a
    [server compromise](https://github.com/xddxdd/nix-cachyos-kernel/issues/110).
    The kernel input, pinned overlay, and host kernel variants remain unchanged.
    [Xinux runs a separate builder](https://github.com/xddxdd/nix-cachyos-kernel/issues/89).
    Cache availability depends on the exact pinned kernel output; a missing output can still
    require local compilation.
  '';
  module = _: {
    nixos = {
      lib,
      userName,
      preservationEnable,
      inputs,
      ...
    }: {
      preservation.preserveAt = lib.mkIf preservationEnable {
        "/persist" = {
          users.${userName} = {
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
            "https://cache.xinux.uz"
          ];

          trusted-public-keys = [
            "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            "matrix.cachix.org-1:uZWavEIj0/oIRHPjh+OG586y4nXBlyI0xkYfZBfDx7w="
            "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
            "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
            "cache.xinux.uz:BXCrtqejFjWzWEB9YuGB7X2MV4ttBur1N8BkwQRdH+0="
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
