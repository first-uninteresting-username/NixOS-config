# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{inputs, ...}: {
  name = "john";
  role = "nixos";
  system = "x86_64-linux";
  ids = ["DE" "audio" "browser" "home-manager" "host-john" "hostname" "input" "iso" "iso-graphical" "locale" "networking-minimal" "nix" "power" "preservation" "secretless-git" "shell" "ssh-debug" "stylix" "sudo" "tty" "user" "wayland" "xdg"];
  args = {
    userName = "nixos";
    userEnable = true;
    preservationEnable = false;
    shell = {
      enable = true;
      name = "nushell";
    };
    theme = {
      enable = true;
      base16Scheme = "gruvbox-dark";
      image = {
        enable = true;
        width = "1920";
        height = "1080";
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
    userHashedPassword = "$y$j9T$e3RBMYwLteags209/SMBP0$f4bZILjV/MjNCquJFQmxL55.q6SdtN.gbATDv7Mds50";
  };
}
