# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{pkgs, ...}: {
  languages.nix.enable = true;

  packages = with pkgs; [
    yamllint
    alejandra
    nixd
  ];

  # Trust me, you don't want to run the checks, eval is enough for basic dev
  scripts.flake-check.exec = ''
    nix flake check --no-build
  '';

  files.".vscode/settings.json" = {
    copyMode = "copy";
    json = {
      editor.defaultFormatter = "esbenp.prettier-vscode";
      editor.formatOnSave = true;
      "[nix]" = {
        editor.defaultFormatter = "jnoortheen.nix-ide";
      };
      nix.enableLanguageServer = true;
      nix.serverPath = "nixd";
      nix.formatterPath = "alejandra";
    };
  };

  files.".zed/settings.json" = {
    copyMode = "copy";
    json = {
      languages.Nix = {
        language_servers = [
          "nixd"
          "!nil"
          "..."
        ];
        formatter = {
          external = {
            command = "alejandra";
            arguments = [
              "--quiet"
              "--"
            ];
          };
        };
      };
    };
  };

  git-hooks.hooks = {
    alejandra.enable = true;
  };

  devcontainer = {
    enable = true;
    settings.customizations.vscode.extensions = [
      "jnoortheen.nix-ide"
      "esbenp.prettier-vscode"
      "wakatime.vscode-wakatime"
    ];
  };
}
