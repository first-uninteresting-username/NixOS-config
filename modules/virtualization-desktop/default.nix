# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "virtualization-desktop";
  ids = ["virtualization-desktop"];
  state = {
    nixos.directories = [
      "/var/lib/containers"
    ];
    home.directories = [
      ".local/share/containers"
      ".config/containers"
      ".local/share/distrobox"
      ".local/share/applications/"
      ".lima"
      ".cache/lima"
    ];
  };
  module = _: {
    nixos = _: {
      virtualisation = {
        podman = {
          enable = true;
          dockerCompat = true;
          defaultNetwork.settings.dns_enabled = true;
        };
      };
      boot.kernelModules = [
        "binder_linux"
        "ashmem_linux"
      ];
    };
    home = {
      pkgs,
      config,
      ...
    }: {
      home.packages = with pkgs; [
        lima
      ];
      programs = {
        distrobox = {
          enable = true;
          settings = {
            container_manager = "podman";
            container_generate_entry = 1;
            container_user_custom_home = "${config.home.homeDirectory}/homes/default";
          };
        };
      };
    };
  };
}
