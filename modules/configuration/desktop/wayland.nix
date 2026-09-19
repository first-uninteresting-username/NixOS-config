# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
_: {
  flake = {
    nixosModules.wayland = {
      pkgs,
      config,
      ...
    }: {
      hardware.graphics = {
        enable = true;
        enable32Bit = pkgs.stdenv.hostPlatform.isx86_64;
      };
      security.polkit.enable = true;
      environment.sessionVariables = {
        NIXOS_OZONE_WL = "1";
        SDL_VIDEODRIVER = "wayland";
        _JAVA_AWT_WM_NONREPARENTING = "1";
        MOZ_ENABLE_WAYLAND = "1";
      };
      services.dbus.enable = true;
      environment.systemPackages = with pkgs; [
        wayland
        wayland-protocols
        wl-clipboard
      ];
      home-manager.users.${config.custom.user.name} = _: {
        home.sessionVariables = {
          NIXOS_OZONE_WL = "1";
          SDL_VIDEODRIVER = "wayland";
          _JAVA_AWT_WM_NONREPARENTING = "1";
          MOZ_ENABLE_WAYLAND = "1";
        };
      };
    };
  };
}
