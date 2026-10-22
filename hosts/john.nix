# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  name = "john";
  role = "nixos";
  system = "x86_64-linux";
  ids = ["GNOME" "audio" "browser" "home-manager" "host-john" "hostname" "input" "iso" "iso-graphical" "locale" "networking-minimal" "nix" "power" "preservation" "git" "secrets" "shell" "nushell" "ssh-debug" "stylix" "sudo" "tty" "user" "wayland" "xdg"];
  args = {
    userName = "nixos";
    userEnable = true;
    secretsEnable = false;
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
    userHashedPassword = "$y$j9T$e3RBMYwLteags209/SMBP0$f4bZILjV/MjNCquJFQmxL55.q6SdtN.gbATDv7Mds50";
  };
}
