# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  name = "nisha";
  role = "nixos";
  system = "aarch64-linux";
  ids = ["XFCE" "audio" "browser" "desktop-password" "fish" "git" "home-manager" "host-nisha" "hostname" "locale" "networking-minimal" "nix" "secrets" "shell" "ssh" "ssh-server" "stylix" "sudo" "user" "xdg"];
  args = {
    userName = "nixi";
    userEnable = true;
    secretsEnable = true;
    preservationEnable = false;
    theme = {
      enable = true;
      base16Scheme = "gruvbox-dark";
      image = {
        enable = true;
        width = "1920";
        height = "1080";
      };
    };
  };
}
