# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  description = "first-uninteresting-username's NixOS config";

  nixConfig = {
    extra-substituters = [
      "https://matrix.cachix.org"
    ];

    extra-trusted-public-keys = [
      "matrix.cachix.org-1:uZWavEIj0/oIRHPjh+OG586y4nXBlyI0xkYfZBfDx7w="
    ];
  };

  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    import-tree = {
      url = "github:vic/import-tree";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:first-uninteresting-username/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    preservation.url = "github:nix-community/preservation";

    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixflix = {
      url = "github:kiriwalawren/nixflix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-crab = {
      url = "github:ItszFinn/nix-crab";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    llm-agents = {
      url = "github:numtide/llm-agents.nix";
    };

    hack = {
      url = "github:first-uninteresting-username/hack";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hexecute-gnome = {
      url = "github:first-uninteresting-username/Hexecute-gnome";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-registry = {
      url = "github:nixos/flake-registry";
      flake = false;
    };

    nix-github-actions = {
      url = "github:nix-community/nix-github-actions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "x86_64-linux"
        # Literally useless
        "aarch64-linux"
      ];

      imports = [
        (inputs.import-tree ./modules)
        (inputs.import-tree ./packages)
        (inputs.import-tree ./checks)
        (inputs.import-tree ./github-actions)
        (inputs.import-tree.match ".*/[^/]+/default\\.nix" ./hosts)
      ];
      perSystem = {pkgs, ...}: {
        formatter = pkgs.alejandra;
      };
    };
}
