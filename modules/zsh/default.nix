# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "zsh";
  ids = ["zsh"];
  module = _: {
    nixos = {
      lib,
      pkgs,
      userName,
      preservationEnable,
      ...
    }: {
      config = {
        preservation.preserveAt = lib.mkIf preservationEnable {
          "/persist" = {
            users.${userName} = {
              directories = [
                ".config/zsh"
              ];
            };
          };
        };

        users.users.${userName}.shell = pkgs.zsh;
        programs.zsh.enable = true;
      };
    };
    home = {config, ...}: {
      programs = {
        zsh = {
          enable = true;
          autocd = true;
          enableCompletion = true;
          autosuggestion.enable = true;
          syntaxHighlighting.enable = true;
          dotDir = "${config.xdg.configHome}/zsh";
          oh-my-zsh = {
            enable = true;
            plugins = [
              "git"
              "copyfile"
              "copypath"
              "sudo"
            ];
            theme = "";
          };
          initContent = ''
            fastfetch
          '';
        };

        nix-index = {enableZshIntegration = true;};
        starship = {enableZshIntegration = true;};
        atuin = {enableZshIntegration = true;};
        eza = {enableZshIntegration = true;};
        zoxide = {enableZshIntegration = true;};
        television = {enableZshIntegration = true;};
        pay-respects = {enableZshIntegration = true;};
        yazi = {enableZshIntegration = true;};
        nix-your-shell = {enableZshIntegration = true;};
        broot = {enableZshIntegration = true;};
        fzf = {enableZshIntegration = true;};
        carapace = {enableZshIntegration = true;};
        devenv = {enableZshIntegration = true;};
        direnv = {enableZshIntegration = true;};
      };
    };
  };
}
