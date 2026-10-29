# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "fish";
  ids = ["fish"];
  state = {
    home.directories = [
      ".local/share/fish"
      ".cache/fish"
    ];
  };
  module = _: {
    nixos = {
      pkgs,
      userName,
      ...
    }: {
      config = {
        users.users.${userName}.shell = pkgs.fish;
        programs.fish.enable = true;
      };
    };
    home = _: {
      programs = {
        fish = {
          enable = true;
          functions = {
            copyfile = ''
              wl-copy < $argv[1]
            '';
            copypath = ''
              printf %s $PWD | wl-copy
            '';
            starship_transient_prompt_func = ''
              starship module character
            '';
          };
          interactiveShellInit = ''
            set -g fish_greeting
          '';
        };

        nix-index = {enableFishIntegration = true;};
        starship = {
          enableFishIntegration = true;
          enableTransience = true;
          settings = {
            add_newline = false;
            character = {
              success_symbol = "[❯](bold green)";
              error_symbol = "[❯](bold red)";
            };
          };
        };
        atuin = {enableFishIntegration = true;};
        eza = {enableFishIntegration = true;};
        zoxide = {enableFishIntegration = true;};
        television = {enableFishIntegration = true;};
        pay-respects = {enableFishIntegration = true;};
        yazi = {enableFishIntegration = true;};
        nix-your-shell = {enableFishIntegration = true;};
        broot = {enableFishIntegration = true;};
        fzf = {enableFishIntegration = true;};
        carapace = {enableFishIntegration = true;};
        devenv = {enableFishIntegration = true;};
        direnv = {enableFishIntegration = true;};
      };
    };
  };
}
