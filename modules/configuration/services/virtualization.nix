# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
_: {
  flake = {
    nixosModules.virtualization-desktop = {
      lib,
      config,
      ...
    }: {
      preservation.preserveAt = lib.mkIf config.custom.preservation.enable {
        "/persist" = {
          directories = [
            "/var/lib/containers"
          ];
          users.${config.custom.user.name} = {
            directories = [
              ".local/share/containers"
              ".config/containers"
              ".local/share/distrobox"
              ".local/share/applications/"
              ".lima"
              ".cache/lima"
            ];
          };
        };
      };
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
      home-manager.users.${config.custom.user.name} = {
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
  };
}
