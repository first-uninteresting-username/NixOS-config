# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  name = "victim";
  role = "nixos";
  system = "x86_64-linux";
  ids = ["GNOME" "IDE" "agents" "audio" "bootloader" "browser" "desktop-password" "gaming" "git" "home-manager" "host-victim" "hostname" "input" "languages" "llama-cpp" "locale" "moonlight" "networking-desktop" "nix" "power" "preservation" "printing" "programs-desktop" "orchard-cli" "secrets" "shell" "nushell" "hack" "slick" "smart" "solaar" "ssh" "stylix" "sudo" "tty" "update" "user" "virtualization-desktop" "wayland" "xdg"];
  args = {
    userName = "nixi";
    userEnable = true;
    secretsEnable = true;
    preservationEnable = true;
    theme = {
      enable = true;
      base16Scheme = "gruvbox-dark";
      image = {
        enable = true;
        width = "2560";
        height = "1440";
      };
    };
  };
}
