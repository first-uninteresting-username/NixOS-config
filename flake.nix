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

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      # Fork branch adds a Gram target.
      url = "github:first-uninteresting-username/stylix/gram";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    firefox-addons = {
      # Fetch Git directly because GitLab's default-branch commits API returns HTTP 403.
      url = "git+https://gitlab.com/rycee/nur-expressions.git?dir=pkgs/firefox-addons&ref=master&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    preservation.url = "github:nix-community/preservation";

    # No nixpkgs follows: the kernels must match Chaotic-Nyx builds to come from its cache
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixflix = {
      url = "github:kiriwalawren/nixflix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-crab = {
      url = "github:first-uninteresting-username/nix-crab/9a566afbe3d494060c79ef78798845e727a2232d";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    llm-agents = {
      url = "github:numtide/llm-agents.nix";
    };

    hack = {
      url = "github:first-uninteresting-username/hack";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hackastats = {
      url = "github:first-uninteresting-username/hackastats";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zed-extensions = {
      url = "github:SwornSystems/nix-zed-extensions";
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

    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    slick = {
      url = "github:3kh0/slick";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    r-sent = {
      url = "github:first-uninteresting-username/r-sent";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs: let
    inherit (inputs.nixpkgs) lib;
    systems = [
      "x86_64-linux"
      # Literally useless
      "aarch64-linux"
    ];
    registry =
      (import ./lib/modules {
        inherit inputs;
        inherit (inputs) self;
      }).discover {
        inherit systems;
        modulesDir = ./modules;
        hostsDir = ./hosts;
        argumentsDir = ./arguments;
      };
    ci = import ./github-actions {inherit lib inputs registry systems;};
    deployment = import ./deploy {inherit lib inputs systems;};
  in {
    inherit (registry) nixosModules homeModules nixosConfigurations homeConfigurations;
    inherit (registry) packages checks;
    inherit (ci) githubActions hosts regressionChecks;
    inherit (deployment) deploy;
    apps = lib.genAttrs systems (system:
      deployment.apps.${system}
      // import ./github-actions/package-updates.nix {
        inherit lib;
        inherit (inputs) self;
        pkgs = inputs.nixpkgs.legacyPackages.${system};
        packages = registry.packages.${system};
      });
    formatter = lib.genAttrs systems (system: inputs.nixpkgs.legacyPackages.${system}.alejandra);
    lib = {
      # Checks and packages use these through self; the registry itself stays internal.
      modules = {inherit (registry) mkHost commonArgs;};
    };
  };
}
