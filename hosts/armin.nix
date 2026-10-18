# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  name = "armin";
  role = "nixos";
  system = "x86_64-linux";
  ids = ["GNOME" "IDE" "agents" "audio" "bootloader" "browser" "desktop-password" "gaming" "git" "home-manager" "host-armin" "hostname" "input" "languages" "llama-cpp" "locale" "moonlight" "networking-desktop" "nix" "power" "preservation" "printing" "programs-desktop" "secrets" "shell" "nushell" "hack" "slick" "smart" "ssh" "stylix" "sudo" "tty" "update" "user" "virtualization-desktop" "wayland" "xdg"];
  args = {
    userName = "nixi";
    userEnable = true;
    preservationEnable = true;
    theme = {
      enable = true;
      base16Scheme = "gruvbox-dark";
      image = {
        enable = true;
        width = "2256";
        height = "1504";
      };
    };
  };
}
