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

        starship = {
          enableTransience = true;
          settings = {
            add_newline = false;
            character = {
              success_symbol = "[❯](bold green)";
              error_symbol = "[❯](bold red)";
            };
          };
        };
      };
    };
  };
}
