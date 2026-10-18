# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{inputs, ...}: {
  name = "victim";
  role = "nixos";
  system = "x86_64-linux";
  ids = ["DE" "IDE" "agents" "audio" "bootloader" "browser" "desktop-password" "gaming" "git" "home-manager" "host-victim" "hostname" "input" "languages" "llama-cpp" "locale" "moonlight" "networking-desktop" "nix" "power" "preservation" "printing" "programs-desktop" "secrets" "shell" "shell-secret-programs" "slick" "smart" "ssh" "stylix" "sudo" "tty" "update" "user" "virtualization-desktop" "wayland" "xdg"];
  args = {
    userName = "nixi";
    userEnable = true;
    preservationEnable = true;
    shell = {
      enable = true;
      name = "nushell";
    };
    theme = {
      enable = true;
      base16Scheme = "gruvbox-dark";
      image = {
        enable = true;
        width = "2560";
        height = "1440";
      };
      icons = {
        name = "MoreWaita";
        package = inputs.nixpkgs.legacyPackages.x86_64-linux.morewaita-icon-theme;
      };
    };
    desktop = {
      enable = true;
      name = "gnome";
    };
  };
}
