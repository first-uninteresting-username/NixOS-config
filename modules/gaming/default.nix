# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "gaming";
  ids = ["gaming"];
  module = _: {
    nixos = {
      lib,
      userName,
      preservationEnable,
      inputs,
      ...
    }: {
      imports = [
        inputs.nix-crab.nixosModules.default
      ];

      programs.nix-crab = {
        slssteam.enable = true;
        slssteam-moon.enable = true;
        # Both pinned and current nix-crab require this for Steam hook injection.
        cloudredirect.enable = true;
        cloudredirect.moon.enable = true;
      };

      preservation.preserveAt = lib.mkIf preservationEnable {
        "/persist" = {
          users.${userName} = {
            directories = [
              ".config/lutris"
              ".local/share/lutris"
              ".cache/lutris"
              ".local/share/PrismLauncher"
              ".config/PrismLauncher"
              ".config/heroic"
              ".local/share/heroic"
              ".local/share/keyrings"
              ".cache/ProtonPlus"
              ".luanti"
              ".local/share/Steam"
              ".config/SLSsteam"
              ".config/CloudRedirect"
              ".local/share/Lumen"
            ];
            files = [
              # User-level files to persist (relative to $HOME)
            ];
          };
        };
      };
    };
    home = {
      lib,
      inputs,
      pkgs,
      ...
    }: {
      imports = [
        inputs.nix-crab.homeModules.default
      ];

      home.packages = with pkgs; [
        heroic
        protonplus
        luanti
      ];

      home.activation.steamCefAndStplugin = lib.hm.dag.entryAfter ["writeBoundary"] ''
        mkdir -p "$HOME/.local/share/Steam/config/stplug-in"
        touch "$HOME/.local/share/Steam/.cef-enable-remote-debugging"
      '';

      systemd.user.services.nix-crab-lumen.Service = {
        Environment = "PATH=${lib.makeBinPath [pkgs.unzip]}:/run/current-system/sw/bin:/usr/bin:/bin";
        Restart = lib.mkForce "always";
        RestartSec = 5;
      };

      programs = {
        nix-crab = {
          luatools = {
            enable = true;
            lumenService = true;
          };
          cloudredirect.moon.enable = true;
        };
        lutris = {
          enable = true;
        };
        prismlauncher = {
          enable = true;
        };
      };
    };
  };
  packages = {
    inputs,
    lib,
    pkgs,
    system,
    ...
  }: let
    name = "slsteam-moon";

    profile =
      (inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          inputs.nix-crab.nixosModules.default
          {
            nixpkgs.config.allowUnfree = true;
            programs.nix-crab.slssteam-moon.enable = true;
            system.stateVersion = "26.11";
          }
        ];
      }).config.programs.steam.package.drvAttrs.profile or "";

    ldAudit = let
      lines = lib.filter (line: lib.hasPrefix "LD_AUDIT=" line) (lib.splitString "\n" profile);
    in
      lib.concatMap (line: lib.splitString ":" (lib.removePrefix "LD_AUDIT=" line)) lines;

    artefacts = lib.filter (path: lib.hasInfix "-${name}-" path) ldAudit;
  in
    lib.optionalAttrs (system == "x86_64-linux") {
      slsteam-moon =
        if artefacts == []
        then throw "no ${name} path in the Steam wrapper's LD_AUDIT, so its derivation cannot be reached"
        else
          pkgs.runCommand name {} ''
            mkdir -p "$out"
            cp ${lib.concatStringsSep " " artefacts} "$out/"
          '';
    };
}
