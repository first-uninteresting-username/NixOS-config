# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  name = "wall-e";
  role = "nixos";
  system = "x86_64-linux";
  ids = ["home-manager" "host-wall-e" "hostname" "input" "iso" "iso-terminal" "locale" "networking-minimal" "nix" "power" "preservation" "secretless-git" "shell" "nushell" "ssh-debug" "stylix" "sudo" "tty" "user" "xdg"];
  args = {
    userName = "nixos";
    userEnable = true;
    preservationEnable = false;
    theme = {
      enable = true;
      base16Scheme = "gruvbox-dark";
      image = {
        enable = false;
        width = "1920";
        height = "1080";
      };
    };
    userHashedPassword = "$y$j9T$e3RBMYwLteags209/SMBP0$f4bZILjV/MjNCquJFQmxL55.q6SdtN.gbATDv7Mds50";
  };
}
